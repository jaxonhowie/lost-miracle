package com.lostmiracle.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;
import com.lostmiracle.common.ApiResponse;
import com.lostmiracle.module.character.dto.CharacterSummaryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class JacksonConfigTest {

    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
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
}
