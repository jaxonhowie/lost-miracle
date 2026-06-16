package com.lostmiracle.module.spawn.entity;

import java.time.LocalDateTime;

public class DungeonSpawnSlotEntity {

    private Long id;
    private String dungeonId;
    private String spawnType;
    private String monsterId;
    private int slotIndex;
    private long respawnAt;
    private Long engagedCharacterId;
    private LocalDateTime updatedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getDungeonId() { return dungeonId; }
    public void setDungeonId(String dungeonId) { this.dungeonId = dungeonId; }
    public String getSpawnType() { return spawnType; }
    public void setSpawnType(String spawnType) { this.spawnType = spawnType; }
    public String getMonsterId() { return monsterId; }
    public void setMonsterId(String monsterId) { this.monsterId = monsterId; }
    public int getSlotIndex() { return slotIndex; }
    public void setSlotIndex(int slotIndex) { this.slotIndex = slotIndex; }
    public long getRespawnAt() { return respawnAt; }
    public void setRespawnAt(long respawnAt) { this.respawnAt = respawnAt; }
    public Long getEngagedCharacterId() { return engagedCharacterId; }
    public void setEngagedCharacterId(Long engagedCharacterId) { this.engagedCharacterId = engagedCharacterId; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
