package com.lostmiracle.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "lost-miracle")
public class LostMiracleProperties {

    private final Jwt jwt = new Jwt();
    private final Character character = new Character();
    private final Save save = new Save();

    public Jwt getJwt() {
        return jwt;
    }

    public Character getCharacter() {
        return character;
    }

    public Save getSave() {
        return save;
    }

    public static class Jwt {
        private String secret;
        private long expirationSeconds = 7200;

        public String getSecret() {
            return secret;
        }

        public void setSecret(String secret) {
            this.secret = secret;
        }

        public long getExpirationSeconds() {
            return expirationSeconds;
        }

        public void setExpirationSeconds(long expirationSeconds) {
            this.expirationSeconds = expirationSeconds;
        }
    }

    public static class Character {
        private int maxSlotsPerUser = 3;

        public int getMaxSlotsPerUser() {
            return maxSlotsPerUser;
        }

        public void setMaxSlotsPerUser(int maxSlotsPerUser) {
            this.maxSlotsPerUser = maxSlotsPerUser;
        }
    }

    public static class Save {
        private int maxBytes = 524288;

        public int getMaxBytes() {
            return maxBytes;
        }

        public void setMaxBytes(int maxBytes) {
            this.maxBytes = maxBytes;
        }
    }
}
