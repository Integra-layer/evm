# Integra Network - Node Information

## Network Configuration
- **Chain ID:** `integra-1`
- **EVM Chain ID:** `26217`
- **Token Denom:** `IRL` (base unit: `airl` with 18 decimals)
- **Bech32 Prefix:** `integra`

---

## Node 1 - Primary Validator
| Property | Value |
|----------|-------|
| **IP Address** | `165.227.118.77` |
| **Hostname** | `integra-main-net-node-1` |
| **Node ID** | `86cb264b4e95de268458942d53b749ecfc430aa0` |
| **Validator Name** | `validator1` |
| **Validator Address** | `integra1a6pz78dgnax2atz2l59em2j6y0uf5vl2kd7mmr` |
| **P2P Address** | `86cb264b4e95de268458942d53b749ecfc430aa0@165.227.118.77:26656` |

### Mnemonic (KEEP SECURE!)
```
salt expose catalog fat early visa used source cement bless goat bubble shed humble situate detail wrist common liquid camp fence transfer space airport
```

---

## Node 2 - Validator
| Property | Value |
|----------|-------|
| **IP Address** | `159.65.168.118` |
| **Hostname** | `integra-main-net-node-2` |
| **Node ID** | `b1cf2539379b96f6f43f56915ae44a04d4e4955a` |
| **Validator Name** | `validator2` |
| **Validator Address** | `integra1ysu0ae7vr0v2ljyl2jcuzukqj6ekqxtcagkx8k` |
| **P2P Address** | `b1cf2539379b96f6f43f56915ae44a04d4e4955a@159.65.168.118:26656` |

### Mnemonic (KEEP SECURE!)
```
toilet total pull differ inner violin ten segment evil spread outer ribbon shine blossom someone near fiscal fluid regret inflict sword report almost dolphin
```

---

## Node 3 - Validator
| Property | Value |
|----------|-------|
| **IP Address** | `104.131.34.167` |
| **Hostname** | `integra-main-net-node-3` |
| **Node ID** | `9a05c7393708d16faa43518a8c73104b6863be37` |
| **Validator Name** | `validator3` |
| **Validator Address** | `integra15zkelldu3ymt77qr3haptqc8ztrrp2kc3pr4wn` |
| **P2P Address** | `9a05c7393708d16faa43518a8c73104b6863be37@104.131.34.167:26656` |

### Mnemonic (KEEP SECURE!)
```
rabbit first token talent beyond mimic once cigar use detail quality pool body upon slender question observe arrive return blind law luxury cactus nothing
```

---

## Persistent Peers String
Use this in `config.toml` for all nodes:
```
86cb264b4e95de268458942d53b749ecfc430aa0@165.227.118.77:26656,b1cf2539379b96f6f43f56915ae44a04d4e4955a@159.65.168.118:26656,9a05c7393708d16faa43518a8c73104b6863be37@104.131.34.167:26656
```

---

## Ports Configuration
| Port | Service |
|------|---------|
| 26656 | P2P |
| 26657 | RPC |
| 26658 | ABCI |
| 8545 | EVM JSON-RPC |
| 8546 | EVM WebSocket |
| 1317 | REST API |
| 9090 | gRPC |

---

## Setup Status
- [x] Binary built on all nodes
- [x] Nodes initialized with chain-id `integra-1`
- [x] Validator keys generated
- [ ] Genesis configured with `airl` denom
- [ ] Genesis accounts added
- [ ] Gentxs created and collected
- [ ] Network started

---

## Quick SSH Access
```bash
# Node 1
ssh root@165.227.118.77

# Node 2
ssh root@159.65.168.118

# Node 3
ssh root@104.131.34.167
```

---

*Generated: January 5, 2026*


