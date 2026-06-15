package com.lostmiracle.module.mail.dto;

import java.util.Map;

public record MailResponse(
        long id,
        String title,
        String body,
        Map<String, Object> attachments,
        boolean claimed,
        long createdAt
) {
}
