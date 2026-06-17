package com.lostmiracle.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.admin.dto.GmAuditLogResponse;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class JacksonConfigTest {

    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        SimpleModule module = new SimpleModule();
        module.addSerializer(Long.class, ToStringSerializer.instance);
        module.addSerializer(long.class, ToStringSerializer.instance);
        objectMapper.registerModule(module);
    }

    @Test
    void serializesSnowflakeIdsAsJsonStrings() throws Exception {
        var summary = new CharacterSummaryResponse(
                2066330097169854473L,
                "冒险者",
                "warrior",
                1,
                100,
                "bone_crypt",
                1781574681L,
                1L
        );
        var json = objectMapper.writeValueAsString(ApiResponse.ok(summary));
        assertThat(json).contains("\"id\":\"2066330097169854473\"");
        assertThat(json).doesNotContain("\"id\":2066330097169854473");
    }

    @Test
    void serializesLocalDateTime() throws Exception {
        var auditLog = new GmAuditLogResponse(
                1L,
                2L,
                "SAVE_REPLACE",
                "character",
                "2066330097169854474",
                "{\"reason\":\"test\"}",
                "127.0.0.1",
                LocalDateTime.of(2026, 6, 17, 11, 0, 25)
        );
        var json = objectMapper.writeValueAsString(ApiResponse.ok(auditLog));
        assertThat(json).contains("\"createdAt\":\"2026-06-17T11:00:25\"");
    }
}
