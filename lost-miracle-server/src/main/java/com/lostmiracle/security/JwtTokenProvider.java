package com.lostmiracle.security;

import com.lostmiracle.config.LostMiracleProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

@Component
public class JwtTokenProvider {

    private final SecretKey secretKey;
    private final long expirationSeconds;

    public JwtTokenProvider(LostMiracleProperties properties) {
        String secret = properties.getJwt().getSecret();
        if (secret == null || secret.length() < 32) {
            throw new IllegalStateException("lost-miracle.jwt.secret must be at least 32 characters");
        }
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationSeconds = properties.getJwt().getExpirationSeconds();
    }

    public String createToken(Long userId, String username) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("username", username)
                .audience().add("game").and()
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(expirationSeconds)))
                .signWith(secretKey)
                .compact();
    }

    public UserPrincipal parseToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        if (!isGameAudience(claims)) {
            throw new IllegalArgumentException("invalid game token audience");
        }
        Long userId = Long.parseLong(claims.getSubject());
        String username = claims.get("username", String.class);
        return new UserPrincipal(userId, username);
    }

    private static boolean isGameAudience(Claims claims) {
        if (claims.getAudience() != null && claims.getAudience().contains("game")) {
            return true;
        }
        return "game".equals(claims.get("aud", String.class));
    }

    public long getExpirationSeconds() {
        return expirationSeconds;
    }
}
