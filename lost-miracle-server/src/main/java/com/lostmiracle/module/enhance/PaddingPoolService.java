package com.lostmiracle.module.enhance;

import com.lostmiracle.config.LostMiracleProperties;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PaddingPoolService {

    private static final String KEY_GLOBAL_POINTS = "enhance:padding:global";

    private static final DefaultRedisScript<Long> CONSUME_PITY_SCRIPT = new DefaultRedisScript<>(
            """
                    local current = tonumber(redis.call('GET', KEYS[1]) or '0')
                    local threshold = tonumber(ARGV[1])
                    if current >= threshold then
                      redis.call('DECRBY', KEYS[1], threshold)
                      return 1
                    end
                    return 0
                    """,
            Long.class
    );

    private final StringRedisTemplate redisTemplate;
    private final LostMiracleProperties properties;

    public PaddingPoolService(StringRedisTemplate redisTemplate, LostMiracleProperties properties) {
        this.redisTemplate = redisTemplate;
        this.properties = properties;
    }

    public int getThreshold() {
        return properties.getEnhance().getPadding().getThreshold();
    }

    public int getPoints() {
        String value = redisTemplate.opsForValue().get(KEY_GLOBAL_POINTS);
        if (value == null || value.isBlank()) {
            return 0;
        }
        return Math.max(0, Integer.parseInt(value));
    }

    public double getBonusRate() {
        return properties.getEnhance().getPadding().getBonusRate();
    }

    public boolean isPityReady() {
        return getPoints() >= getThreshold();
    }

    public int addPoints(int amount) {
        if (amount <= 0) {
            return getPoints();
        }
        Long result = redisTemplate.opsForValue().increment(KEY_GLOBAL_POINTS, amount);
        return result == null ? getPoints() : Math.max(0, result.intValue());
    }

    public boolean tryConsumePity() {
        int threshold = getThreshold();
        if (threshold <= 0) {
            return false;
        }
        Long consumed = redisTemplate.execute(
                CONSUME_PITY_SCRIPT,
                List.of(KEY_GLOBAL_POINTS),
                String.valueOf(threshold)
        );
        return consumed != null && consumed == 1L;
    }

    public static int contributionForLevel(int enhanceLevel) {
        return Math.max(1, enhanceLevel + 1);
    }
}
