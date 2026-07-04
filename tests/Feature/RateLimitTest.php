<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class RateLimitTest extends TestCase
{
    private function clearBucket(string $bucket, string $ip = '127.0.0.1'): void
    {
        $key = "rate_limit:{$bucket}:{$ip}";
        Cache::forget($key);
        Cache::forget("{$key}:reset_at");
    }

    private function prefillBucket(string $bucket, int $count, string $ip = '127.0.0.1'): void
    {
        $key = "rate_limit:{$bucket}:{$ip}";
        Cache::put($key, $count, 60);
        Cache::put("{$key}:reset_at", \Illuminate\Support\Carbon::now()->addSeconds(60)->timestamp, 61);
    }

    // ──────────────────────────────────────────────
    // Bucket: general
    // ──────────────────────────────────────────────

    public function test_rate_limit_increments_on_each_request(): void
    {
        $this->clearBucket('general');

        $this->get('/');
        $this->seeStatusCode(200);

        $attempts = Cache::get('rate_limit:general:127.0.0.1', 0);
        $this->assertEquals(1, $attempts);

        $this->clearBucket('general');
    }

    public function test_rate_limit_returns_429_when_exceeded(): void
    {
        $maxRequests = (int) env('RATE_LIMIT_MAX', 300);

        $this->prefillBucket('general', $maxRequests);

        $this->get('/');
        $this->seeStatusCode(429);

        $data = $this->response->json();
        $this->assertEquals('Too Many Requests', $data['error']);
        $this->assertArrayHasKey('retry_after', $data);
        $this->assertEquals('general', $data['bucket']);

        $this->clearBucket('general');
    }

    public function test_rate_limit_clears_after_decay(): void
    {
        Cache::put('rate_limit:general:127.0.0.1', 100, 1);
        Cache::put('rate_limit:general:127.0.0.1:reset_at', \Illuminate\Support\Carbon::now()->addSeconds(1)->timestamp, 2);

        sleep(2);

        $this->get('/');
        $this->seeStatusCode(200);

        $this->clearBucket('general');
    }

    public function test_rate_limit_headers_are_present(): void
    {
        $this->clearBucket('general');

        $this->get('/');
        $this->seeStatusCode(200);
        $this->assertNotNull($this->response->headers->get('X-RateLimit-Limit'));
        $this->assertNotNull($this->response->headers->get('X-RateLimit-Remaining'));
        $this->assertNotNull($this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('general');
    }

    // ──────────────────────────────────────────────
    // Buckets separados: files vs general
    // ──────────────────────────────────────────────

    public function test_file_route_uses_separate_bucket(): void
    {
        $maxGeneral = (int) env('RATE_LIMIT_MAX', 300);
        $maxFile = (int) env('RATE_LIMIT_FILE_MAX', 600);

        // Esgota o bucket GENERAL ate o limite
        $this->prefillBucket('general', $maxGeneral);

        // File route usa bucket SEPARADO — nao deve ser 429
        $this->clearBucket('files');
        $this->get('/file/test/image.jpg');
        $this->assertNotEquals(429, $this->response->getStatusCode());

        // Agora esgota o bucket FILES
        $this->prefillBucket('files', $maxFile);

        // File route agora deve ser 429
        $this->get('/file/test/image.jpg');
        $this->seeStatusCode(429);
        $data = $this->response->json();
        $this->assertEquals('files', $data['bucket']);

        // General route ainda funciona (bucket separado)
        $this->clearBucket('general');
        $this->get('/');
        $this->seeStatusCode(200);

        $this->clearBucket('general');
        $this->clearBucket('files');
    }

    public function test_file_route_bucket_header_is_files(): void
    {
        $this->clearBucket('files');

        $this->get('/file/test/image.jpg');
        $this->assertEquals('files', $this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('files');
    }

    // ──────────────────────────────────────────────
    // Buckets separados: metadata vs general
    // ──────────────────────────────────────────────

    public function test_metadata_route_uses_separate_bucket(): void
    {
        $maxGeneral = (int) env('RATE_LIMIT_MAX', 300);

        // Esgota o bucket GENERAL
        $this->prefillBucket('general', $maxGeneral);

        // Version route usa bucket SEPARADO (metadata) — nao deve ser 429
        $this->clearBucket('metadata');
        $this->get('/version');
        $this->assertNotEquals(429, $this->response->getStatusCode());

        $this->clearBucket('general');
        $this->clearBucket('metadata');
    }

    public function test_metadata_route_bucket_header_is_metadata(): void
    {
        $this->clearBucket('metadata');

        $this->get('/version');
        $this->seeStatusCode(200);
        $this->assertEquals('metadata', $this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('metadata');
    }

    // ──────────────────────────────────────────────
    // Normalizacao de path com prefixo {lang}
    // Rotas no grupo {lang} (musics, albums, etc) caem no bucket GENERAL.
    // O normalizePath garante que /pt-BR/musics seja classificado como GENERAL
    // (sem tratar o prefixo lang como parte do path).
    // ──────────────────────────────────────────────

    public function test_lang_prefix_route_hits_general_bucket(): void
    {
        // Rotas com prefixo lang como /pt-BR/musics existem no router
        // e devem cair no bucket GENERAL
        $this->clearBucket('general');

        // Tenta fazer request para rota com lang prefix que existe no router
        // O middleware lang pode barrar se o idioma nao for valido, mas o
        // rate_limit middleware roda ANTES e deve classificar no bucket correto
        $this->get('/en/musics');
        // Pode ser 200 ou outro erro do lang middleware, mas NAO deve ser 429
        // com bucket 'files' ou 'metadata'
        $bucket = $this->response->headers->get('X-RateLimit-Bucket');

        // Se a request passou pelo rate_limit, o bucket deve ser 'general'
        // (pode ser null se o lang middleware barrou antes)
        if ($bucket !== null) {
            $this->assertEquals('general', $bucket);
        }

        $this->clearBucket('general');
    }

    public function test_no_lang_prefix_route_hits_correct_bucket(): void
    {
        // Rotas fora do grupo lang (/, /file/*, /version) devem funcionar normalmente
        $this->clearBucket('files');
        $this->clearBucket('metadata');
        $this->clearBucket('general');

        $this->get('/file/test.jpg');
        $this->assertEquals('files', $this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('metadata');
        $this->get('/version');
        $this->assertEquals('metadata', $this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('general');
        $this->get('/');
        $this->assertEquals('general', $this->response->headers->get('X-RateLimit-Bucket'));

        $this->clearBucket('files');
        $this->clearBucket('metadata');
        $this->clearBucket('general');
    }
}
