package com.lostmiracle.module.character.entity;

import java.time.LocalDateTime;

public class CharacterEntity {

    private Long id;
    private Long userId;
    private String name;
    private String playerClass;
    private Integer level;
    private Integer powerScore;
    private String currentDungeonId;
    private LocalDateTime lastLoginAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getPlayerClass() { return playerClass; }
    public void setPlayerClass(String playerClass) { this.playerClass = playerClass; }
    public Integer getLevel() { return level; }
    public void setLevel(Integer level) { this.level = level; }
    public Integer getPowerScore() { return powerScore; }
    public void setPowerScore(Integer powerScore) { this.powerScore = powerScore; }
    public String getCurrentDungeonId() { return currentDungeonId; }
    public void setCurrentDungeonId(String currentDungeonId) { this.currentDungeonId = currentDungeonId; }
    public LocalDateTime getLastLoginAt() { return lastLoginAt; }
    public void setLastLoginAt(LocalDateTime lastLoginAt) { this.lastLoginAt = lastLoginAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
