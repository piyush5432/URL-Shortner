package com.urlshortener.service;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class RateLimiterService {

    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    private static final int REQUESTS_PER_MINUTE = 30;
    private static final int REQUESTS_PER_HOUR = 100;
    private static final int MAX_BUCKETS = 100_000;

    public Bucket resolveBucket(String clientIp) {
        if (buckets.size() > MAX_BUCKETS) {
            cleanup();
        }
        return buckets.computeIfAbsent(clientIp, this::createBucket);
    }

    private Bucket createBucket(String clientIp) {
        Bandwidth perMinute = Bandwidth.builder()
                .capacity(REQUESTS_PER_MINUTE)
                .refillGreedy(REQUESTS_PER_MINUTE, Duration.ofMinutes(1))
                .build();

        Bandwidth perHour = Bandwidth.builder()
                .capacity(REQUESTS_PER_HOUR)
                .refillGreedy(REQUESTS_PER_HOUR, Duration.ofHours(1))
                .build();

        return Bucket.builder()
                .addLimit(perMinute)
                .addLimit(perHour)
                .build();
    }

    private void cleanup() {
        buckets.clear();
    }

    public void clearBucket(String clientIp) {
        buckets.remove(clientIp);
    }

    public int getActiveBucketCount() {
        return buckets.size();
    }
}
