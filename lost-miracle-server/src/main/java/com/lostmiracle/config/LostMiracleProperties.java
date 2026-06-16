package com.lostmiracle.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "lost-miracle")
public class LostMiracleProperties {

    private final Jwt jwt = new Jwt();
    private final Gm gm = new Gm();
    private final Character character = new Character();
    private final Save save = new Save();
    private final Enhance enhance = new Enhance();

    public Jwt getJwt() {
        return jwt;
    }

    public Gm getGm() {
        return gm;
    }

    public Character getCharacter() {
        return character;
    }

    public Save getSave() {
        return save;
    }

    public Enhance getEnhance() {
        return enhance;
    }

    public static class Gm {
        private String bootstrapSuperUsername = "super";
        private String bootstrapSuperPassword = "gm-admin-change-me";
        private long expirationSeconds = 7200;
        private long confirmExpirationSeconds = 300;

        public String getBootstrapSuperUsername() {
            return bootstrapSuperUsername;
        }

        public void setBootstrapSuperUsername(String bootstrapSuperUsername) {
            this.bootstrapSuperUsername = bootstrapSuperUsername;
        }

        public String getBootstrapSuperPassword() {
            return bootstrapSuperPassword;
        }

        public void setBootstrapSuperPassword(String bootstrapSuperPassword) {
            this.bootstrapSuperPassword = bootstrapSuperPassword;
        }

        public long getExpirationSeconds() {
            return expirationSeconds;
        }

        public void setExpirationSeconds(long expirationSeconds) {
            this.expirationSeconds = expirationSeconds;
        }

        public long getConfirmExpirationSeconds() {
            return confirmExpirationSeconds;
        }

        public void setConfirmExpirationSeconds(long confirmExpirationSeconds) {
            this.confirmExpirationSeconds = confirmExpirationSeconds;
        }
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

    public static class Enhance {
        private final Padding padding = new Padding();

        public Padding getPadding() {
            return padding;
        }

        public static class Padding {
            private int threshold = 100;
            private double bonusRate = 0.25;

            public int getThreshold() {
                return threshold;
            }

            public void setThreshold(int threshold) {
                this.threshold = threshold;
            }

            public double getBonusRate() {
                return bonusRate;
            }

            public void setBonusRate(double bonusRate) {
                this.bonusRate = bonusRate;
            }
        }
    }
}
