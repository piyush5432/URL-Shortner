package com.urlshortener.service;

import com.urlshortener.dto.ShortenRequest;
import com.urlshortener.dto.ShortenResponse;
import com.urlshortener.dto.UrlAnalyticsResponse;
import com.urlshortener.entity.UrlMapping;
import com.urlshortener.exception.UrlExpiredException;
import com.urlshortener.exception.UrlNotFoundException;
import com.urlshortener.repository.UrlMappingRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.regex.Pattern;

@Service
public class UrlService {

    private static final Logger logger = LoggerFactory.getLogger(UrlService.class);
    private static final int MAX_COLLISION_ATTEMPTS = 5;
    private static final Pattern CUSTOM_ALIAS_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]{3,20}$");

    private final UrlMappingRepository urlMappingRepository;
    private final Base62Encoder base62Encoder;
    private final String baseUrl;

    public UrlService(UrlMappingRepository urlMappingRepository,
                      Base62Encoder base62Encoder,
                      @Value("${app.base-url:http://localhost:8080}") String baseUrl) {
        this.urlMappingRepository = urlMappingRepository;
        this.base62Encoder = base62Encoder;
        this.baseUrl = baseUrl;
    }

    @Transactional
    public ShortenResponse shortenUrl(ShortenRequest request) {
        String shortCode;
        LocalDateTime expiry = calculateExpiry(request.getExpiryDays());

        if (request.getCustomAlias() != null && !request.getCustomAlias().isBlank()) {
            validateCustomAlias(request.getCustomAlias());
            shortCode = request.getCustomAlias();
            if (urlMappingRepository.existsByShortCode(shortCode)) {
                throw new IllegalArgumentException("Custom alias already in use");
            }
        } else {
            shortCode = generateUniqueShortCode();
        }

        UrlMapping mapping = new UrlMapping(shortCode, request.getUrl(), expiry);
        UrlMapping saved = urlMappingRepository.save(mapping);

        logger.info("Created short URL: {} -> {}", shortCode, request.getUrl());

        return buildShortenResponse(saved);
    }

    @Transactional
    public String getOriginalUrl(String shortCode) {
        UrlMapping mapping = urlMappingRepository.findByShortCodeWithLock(shortCode)
                .orElseThrow(() -> new UrlNotFoundException(shortCode));

        if (!mapping.getActive()) {
            throw new UrlNotFoundException(shortCode);
        }

        if (mapping.getExpiry() != null && mapping.getExpiry().isBefore(LocalDateTime.now())) {
            throw new UrlExpiredException(shortCode);
        }

        mapping.incrementClickCount();
        urlMappingRepository.save(mapping);

        logger.debug("Redirecting short code: {} -> {}", shortCode, mapping.getOriginalUrl());

        return mapping.getOriginalUrl();
    }

    @Transactional(readOnly = true)
    public UrlAnalyticsResponse getAnalytics(String shortCode) {
        UrlMapping mapping = urlMappingRepository.findByShortCode(shortCode)
                .orElseThrow(() -> new UrlNotFoundException(shortCode));

        return new UrlAnalyticsResponse(
                mapping.getShortCode(),
                mapping.getOriginalUrl(),
                mapping.getCreatedAt(),
                mapping.getExpiry(),
                mapping.getClickCount(),
                mapping.getActive()
        );
    }

    @Transactional
    public void deactivateUrl(String shortCode) {
        UrlMapping mapping = urlMappingRepository.findByShortCode(shortCode)
                .orElseThrow(() -> new UrlNotFoundException(shortCode));
        mapping.setActive(false);
        urlMappingRepository.save(mapping);
        logger.info("Deactivated short URL: {}", shortCode);
    }

    private String generateUniqueShortCode() {
        for (int i = 0; i < MAX_COLLISION_ATTEMPTS; i++) {
            String code = base62Encoder.generateShortCode();
            if (!urlMappingRepository.existsByShortCode(code)) {
                return code;
            }
            logger.warn("Collision detected for short code: {}, retrying...", code);
        }
        throw new RuntimeException("Failed to generate unique short code after " + MAX_COLLISION_ATTEMPTS + " attempts");
    }

    private void validateCustomAlias(String alias) {
        if (!CUSTOM_ALIAS_PATTERN.matcher(alias).matches()) {
            throw new IllegalArgumentException(
                    "Custom alias must be 3-20 characters and contain only letters, numbers, hyphens, and underscores");
        }
    }

    private LocalDateTime calculateExpiry(Integer expiryDays) {
        if (expiryDays == null || expiryDays <= 0) {
            return null;
        }
        return LocalDateTime.now().plusDays(expiryDays);
    }

    private ShortenResponse buildShortenResponse(UrlMapping mapping) {
        return new ShortenResponse(
                mapping.getShortCode(),
                baseUrl + "/" + mapping.getShortCode(),
                mapping.getOriginalUrl(),
                mapping.getCreatedAt(),
                mapping.getExpiry(),
                mapping.getClickCount()
        );
    }
}
