package com.lostmiracle.module.save;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
public class RateLimitService {

    private static final Logger log = LoggerFactory.getLogger(RateLimitService.class);

    private final StringRedisTemplate redisTemplate;

    public RateLimitService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void checkSaveUpload(long userId, long characterId) {
        check("ratelimit:save:" + userId + ":" + characterId, 60, Duration.ofMinutes(1));
    }

    public void checkEnhanceRoll(long userId, long characterId) {
        check("ratelimit:enhance:" + userId + ":" + characterId, 30, Duration.ofMinutes(1));
    }

    /**
     * 登录接口速率限制：每个 IP 每分钟最多 10 次。
     * 同时覆盖 /auth/login、/auth/register 和 /admin/auth/login。
     */
    public void checkLogin(String clientIp) {
        check("ratelimit:login:" + clientIp, 10, Duration.ofMinutes(1));
    }

    private void check(String key, int maxCount, Duration window) {
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, window);
        }
        if (count != null && count > maxCount) {
            log.warn("rate limit exceeded key={} count={} max={}", key, count, maxCount);
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS, "rate limit exceeded");
        }
    }
}
