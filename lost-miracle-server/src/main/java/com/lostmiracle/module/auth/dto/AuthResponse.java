package com.lostmiracle.module.auth.dto;

public record AuthResponse(
        String accessToken,
        long expiresIn,
        long userId
) {
}
