package com.lostmiracle.security;

import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.admin.GmRole;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

@Component
public class AdminJwtTokenProvider {

    private static final String AUD_ADMIN = "admin";
    private static final String AUD_CONFIRM = "admin_confirm";
    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_CHARACTER_ID = "characterId";
    private static final String CLAIM_SAVE_CHECKSUM = "saveChecksum";

    private final SecretKey secretKey;
    private final long expirationSeconds;
    private final long confirmExpirationSeconds;

    public AdminJwtTokenProvider(LostMiracleProperties properties) {
        String secret = properties.getJwt().getEffectiveAdminSecret();
        if (secret == null || secret.length() < 32) {
            throw new IllegalStateException("lost-miracle.jwt.admin-secret must be at least 32 characters");
        }
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationSeconds = properties.getGm().getExpirationSeconds();
        this.confirmExpirationSeconds = properties.getGm().getConfirmExpirationSeconds();
    }

    public String createToken(Long gmAccountId, String username, GmRole role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(gmAccountId))
                .claim("username", username)
                .claim(CLAIM_ROLE, role.toDbValue())
                .audience().add(AUD_ADMIN).and()
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(expirationSeconds)))
                .signWith(secretKey)
                .compact();
    }

    public GmPrincipal parseToken(String token) {
        Claims claims = parseClaims(token);
        if (claims.getAudience() == null || !claims.getAudience().contains(AUD_ADMIN)) {
            throw new IllegalArgumentException("invalid admin token audience");
        }
        Long gmAccountId = Long.parseLong(claims.getSubject());
        String username = claims.get("username", String.class);
        GmRole role = GmRole.fromString(claims.get(CLAIM_ROLE, String.class));
        return new GmPrincipal(gmAccountId, username, role);
    }

    public String createConfirmToken(long gmAccountId, long characterId, String saveChecksum) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(gmAccountId))
                .audience().add(AUD_CONFIRM).and()
                .claim(CLAIM_CHARACTER_ID, characterId)
                .claim(CLAIM_SAVE_CHECKSUM, saveChecksum)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(confirmExpirationSeconds)))
                .signWith(secretKey)
                .compact();
    }

    public ConfirmTokenClaims parseConfirmToken(String token) {
        Claims claims = parseClaims(token);
        if (claims.getAudience() == null || !claims.getAudience().contains(AUD_CONFIRM)) {
            throw new IllegalArgumentException("invalid confirm token audience");
        }
        long gmAccountId = Long.parseLong(claims.getSubject());
        long characterId = claims.get(CLAIM_CHARACTER_ID, Number.class).longValue();
        String saveChecksum = claims.get(CLAIM_SAVE_CHECKSUM, String.class);
        return new ConfirmTokenClaims(gmAccountId, characterId, saveChecksum);
    }

    public long getExpirationSeconds() {
        return expirationSeconds;
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public record ConfirmTokenClaims(long gmAccountId, long characterId, String saveChecksum) {
    }
}
