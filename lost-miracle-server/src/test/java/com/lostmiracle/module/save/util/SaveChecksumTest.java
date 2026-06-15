package com.lostmiracle.module.save.util;

import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SaveChecksumTest {

    @Test
    void sha256_isDeterministic() {
        String first = SaveChecksum.sha256("{\"player\":{\"level\":1}}");
        String second = SaveChecksum.sha256("{\"player\":{\"level\":1}}");
        assertEquals(first, second);
        assertEquals(64, first.length());
    }
}
