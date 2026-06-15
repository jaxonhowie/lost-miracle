package com.lostmiracle.module.save;

import com.lostmiracle.common.BusinessException;
import com.lostmiracle.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.UUID;

@Service
public class RedisLockService {

    private static final Logger log = LoggerFactory.getLogger(RedisLockService.class);
    private static final Duration LOCK_TTL = Duration.ofSeconds(10);

    private final StringRedisTemplate redisTemplate;

    public RedisLockService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public String acquireSaveLock(long characterId) {
        String key = "lock:save:" + characterId;
        String token = UUID.randomUUID().toString();
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(key, token, LOCK_TTL);
        if (!Boolean.TRUE.equals(acquired)) {
            log.warn("save lock busy characterId={}", characterId);
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS, "save lock busy");
        }
        return token;
    }

    public void releaseSaveLock(long characterId, String token) {
        String key = "lock:save:" + characterId;
        String current = redisTemplate.opsForValue().get(key);
        if (token != null && token.equals(current)) {
            redisTemplate.delete(key);
        }
    }
}
