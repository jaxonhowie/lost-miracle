package com.lostmiracle.support;

import com.lostmiracle.config.LostMiracleProperties;
import com.lostmiracle.module.enhance.PaddingPoolService;
import com.lostmiracle.module.leaderboard.LeaderboardService;
import com.lostmiracle.module.save.RateLimitService;
import com.lostmiracle.module.save.RedisLockService;
import com.lostmiracle.module.save.SaveSnapshotService;
import org.mockito.Mockito;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.core.StringRedisTemplate;

@TestConfiguration
public class IntegrationTestConfig {

    @Bean
    StringRedisTemplate stringRedisTemplate() {
        return Mockito.mock(StringRedisTemplate.class);
    }

    @Bean
    @Primary
    RedisLockService integrationRedisLockService() {
        return new RedisLockService(null) {
            @Override
            public String acquireSaveLock(long characterId) {
                return "integration-test-lock";
            }

            @Override
            public void releaseSaveLock(long characterId, String token) {
            }
        };
    }

    @Bean
    @Primary
    RateLimitService integrationRateLimitService() {
        return new RateLimitService(null) {
            @Override
            public void checkSaveUpload(long userId, long characterId) {
            }

            @Override
            public void checkEnhanceRoll(long userId, long characterId) {
            }
        };
    }

    @Bean
    @Primary
    PaddingPoolService integrationPaddingPoolService(LostMiracleProperties properties) {
        return new PaddingPoolService(null, properties) {
            @Override
            public int getPoints() {
                return 0;
            }

            @Override
            public int addPoints(int amount) {
                return 0;
            }

            @Override
            public boolean tryConsumePity() {
                return false;
            }
        };
    }

    @Bean
    @Primary
    LeaderboardService integrationLeaderboardService() {
        return new LeaderboardService(null, null) {
            @Override
            public void submitPowerScore(com.lostmiracle.module.character.entity.CharacterEntity character) {
            }

            @Override
            public void removeCharacter(long characterId) {
            }
        };
    }

    @Bean
    @Primary
    SaveSnapshotService integrationSaveSnapshotService() {
        return new SaveSnapshotService(null) {
            @Override
            public void snapshotAsync(long characterId, long saveVersion, String saveJson) {
            }
        };
    }
}
