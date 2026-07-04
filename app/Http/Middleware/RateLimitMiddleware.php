<?php

namespace App\Http\Middleware;

use Carbon\Carbon;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class RateLimitMiddleware
{
    /**
     * Rotas que servem conteudo estatico (imagens, musicas, arquivos).
     * Essas rotas usam limites mais altos porque o app desktop faz
     * batch downloads de capas, slides e musicas simultaneamente.
     */
    private const FILE_ROUTES = [
        '/file/',
        '/player',
    ];

    /**
     * Rotas de metadados leves que podem ter limites mais relaxados.
     */
    private const METADATA_ROUTES = [
        '/version',
        '/version_log',
        '/metadata',
    ];

    /**
     * Bucket names para chaves de cache separadas.
     * Cada tipo de rota tem seu proprio contador de requests.
     */
    private const BUCKET_FILE = 'files';
    private const BUCKET_METADATA = 'metadata';
    private const BUCKET_GENERAL = 'general';

    /**
     * Prefixos de idioma que aparecem nas rotas (ex: /pt-BR/file/...).
     * Precisam ser removidos para que o matching funcione corretamente.
     */
    private const LANG_PREFIXES = [
        'pt-BR', 'en', 'es', 'fr', 'de', 'it', 'ru', 'zh', 'ja', 'ko',
    ];

    /**
     * Rate limiting baseado em IP com buckets separados por tipo de rota.
     *
     * Cada tipo de rota (arquivos, metadados, geral) tem seu proprio contador
     * no cache. Isso evita que downloads de arquivos esgotem o bucket de API.
     *
     * Configuravel via .env:
     *   RATE_LIMIT_MAX=300           (max requests gerais/min, default 300)
     *   RATE_LIMIT_FILE_MAX=600      (max requests para arquivos/min, default 600)
     *   RATE_LIMIT_METADATA_MAX=600  (max requests para metadados/min, default 600)
     *   RATE_LIMIT_DECAY=60          (janela em segundos, default 60)
     *
     * Headers de resposta:
     *   X-RateLimit-Limit, X-RateLimit-Remaining, X-Retry-After, X-RateLimit-Bucket
     */
    public function handle(Request $request, Closure $next)
    {
        $decaySeconds = (int) env('RATE_LIMIT_DECAY', 60);

        // Normaliza o path removendo prefixo de idioma (ex: /pt-BR/file/x -> /file/x)
        $normalizedPath = $this->normalizePath($request->path());

        $bucket = $this->resolveBucket($normalizedPath);
        $maxRequests = $this->resolveMaxRequests($bucket);

        $key = "rate_limit:{$bucket}:" . $request->ip();
        $attempts = Cache::get($key, 0);

        if ($attempts >= $maxRequests) {
            $retryAfter = Cache::get("{$key}:reset_at", Carbon::now()->addSeconds($decaySeconds)->timestamp);

            $response = response()->json([
                'error' => 'Too Many Requests',
                'message' => 'Limite de requisicoes excedido. Tente novamente em breve.',
                'retry_after' => $retryAfter - Carbon::now()->timestamp,
                'bucket' => $bucket,
            ], 429);
            $response->headers->set('X-RateLimit-Limit', (string) $maxRequests);
            $response->headers->set('X-RateLimit-Remaining', '0');
            $response->headers->set('X-RateLimit-Bucket', $bucket);
            $response->headers->set('Retry-After', (string) ($retryAfter - Carbon::now()->timestamp));

            return $response;
        }

        Cache::put($key, $attempts + 1, $decaySeconds);

        // Define o timestamp de reset na primeira request
        if ($attempts === 0) {
            Cache::put("{$key}:reset_at", Carbon::now()->addSeconds($decaySeconds)->timestamp, $decaySeconds + 1);
        }

        $remaining = $maxRequests - ($attempts + 1);

        $response = $next($request);

        // StreamedResponse nao tem ->header() (Symfony 6.4+).
        // Usa ->headers->set() que funciona em qualquer Response.
        $response->headers->set('X-RateLimit-Limit', (string) $maxRequests);
        $response->headers->set('X-RateLimit-Remaining', (string) max($remaining, 0));
        $response->headers->set('X-RateLimit-Bucket', $bucket);

        return $response;
    }

    /**
     * Normaliza o path removendo prefixo de idioma (ex: /pt-BR/file/x -> /file/x).
     * Isso garante que rotas com e sem prefixo de idioma sejam classificadas
     * no mesmo bucket e matching funcione corretamente.
     */
    private function normalizePath(string $path): string
    {
        $segments = explode('/', $path);

        if (count($segments) > 1 && in_array($segments[1], self::LANG_PREFIXES, true)) {
            // Remove o primeiro segmento (prefixo de idioma)
            array_shift($segments);
            return '/' . implode('/', $segments);
        }

        return '/' . $path;
    }

    /**
     * Determina o bucket (tipo) da rota com base no path normalizado.
     * Cada bucket tem seu proprio contador de requests no cache.
     */
    private function resolveBucket(string $normalizedPath): string
    {
        foreach (self::FILE_ROUTES as $fileRoute) {
            if (str_starts_with($normalizedPath, $fileRoute)) {
                return self::BUCKET_FILE;
            }
        }

        foreach (self::METADATA_ROUTES as $metaRoute) {
            if ($normalizedPath === $metaRoute) {
                return self::BUCKET_METADATA;
            }
        }

        return self::BUCKET_GENERAL;
    }

    /**
     * Determina o limite maximo de requests com base no bucket.
     */
    private function resolveMaxRequests(string $bucket): int
    {
        return match ($bucket) {
            self::BUCKET_FILE => (int) env('RATE_LIMIT_FILE_MAX', 600),
            self::BUCKET_METADATA => (int) env('RATE_LIMIT_METADATA_MAX', 600),
            default => (int) env('RATE_LIMIT_MAX', 300),
        };
    }
}
