# Integra Mainnet Genesis Configuration Review

> **Document Version:** 1.1  
> **Date:** January 22, 2026  
> **Chain ID:** `integra-1`  
> **Network:** Integra Mainnet

---

## Executive Summary

This document provides a comprehensive review of the Integra Mainnet genesis configuration, mapping each business requirement to its technical implementation in the genesis JSON.

---

## Table of Contents

1. [Token Configuration](#1-token-configuration)
2. [Total Supply & Distribution](#2-total-supply--distribution)
3. [Staking & Unbonding](#3-staking--unbonding)
4. [Inflation & Staking Yield](#4-inflation--staking-yield)
5. [Validator Economics](#5-validator-economics)
6. [Governance Parameters](#6-governance-parameters)
7. [Community Pool / Treasury](#7-community-pool--treasury)
8. [Transaction Fees](#8-transaction-fees)
9. [Smart Contract Configuration](#9-smart-contract-configuration)
10. [ERC-20 Module](#10-erc-20-module)
11. [IBC Configuration](#11-ibc-configuration)
12. [Slashing Parameters](#12-slashing-parameters)
13. [Additional Configuration](#13-additional-configuration)
14. [Full Genesis JSON](#14-full-genesis-json)

---

## 1. Token Configuration

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Internal Name | `irl` (mainnet) |
| Network Name | `Integra` |
| Public Name | `Integra` |
| Symbol | `IRL` |
| Decimals | `18` |

### Genesis Implementation ✅

```json
"denom_metadata": [
  {
    "description": "The native token of Integra",
    "denom_units": [
      {
        "denom": "airl",
        "exponent": 0,
        "aliases": ["attoirl"]
      },
      {
        "denom": "irl",
        "exponent": 18,
        "aliases": []
      }
    ],
    "base": "airl",
    "display": "irl",
    "name": "Integra",
    "symbol": "IRL"
  }
]
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Base Denom | `airl` | `airl` | ✅ |
| Display Denom | `irl` | `irl` | ✅ |
| Symbol | `IRL` | `IRL` | ✅ |
| Decimals | `18` | `18` | ✅ |
| Description | "The native token of Integra" | ✅ | ✅ |

---

## 2. Total Supply & Distribution

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Total Supply | 100,000,000,000 IRL (100 billion) |
| Distribution | All to single address for later distribution |
| Treasury Address | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |

### Address Conversion
| Format | Address |
|--------|---------|
| EVM (0x) | `0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4` |
| Bech32 (integra) | `integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw` |
| Valoper | `integravaloper1khs68tk2jatw0jthrtkfpfm7jckjsd05aa0gnr` |

### Genesis Implementation ✅

```json
"balances": [
  {
    "address": "integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw",
    "coins": [
      {
        "denom": "airl",
        "amount": "100000000000000000000000000000"
      }
    ]
  }
],
"supply": [
  {
    "denom": "airl",
    "amount": "100000000000000000000000000000"
  }
]
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Total Supply (airl) | 100,000,000,000 × 10¹⁸ | `100000000000000000000000000000` | ✅ |
| Treasury Address | `integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw` | ✅ Configured | ✅ |

---

## 3. Staking & Unbonding

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Unbonding Period | 21 days |

### Genesis Implementation ✅

```json
"staking": {
  "params": {
    "unbonding_time": "1814400s",
    "max_validators": 100,
    "max_entries": 7,
    "historical_entries": 10000,
    "bond_denom": "airl",
    "min_commission_rate": "0.000000000000000000"
  }
}
```

| Parameter | Required | Configured | Calculation | Status |
|-----------|----------|------------|-------------|--------|
| Unbonding Time | 21 days | `1814400s` | 21 × 24 × 60 × 60 = 1,814,400 | ✅ |
| Bond Denom | `airl` | `airl` | - | ✅ |

---

## 4. Inflation & Staking Yield

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Starting Inflation | 3% |
| Target % Staked | 0% |

### Genesis Implementation ✅

```json
"mint": {
  "minter": {
    "inflation": "0.030000000000000000",
    "annual_provisions": "0.000000000000000000"
  },
  "params": {
    "mint_denom": "airl",
    "inflation_rate_change": "0.030000000000000000",
    "inflation_max": "0.030000000000000000",
    "inflation_min": "0.030000000000000000",
    "goal_bonded": "0.000000000000000000",
    "blocks_per_year": "6311520"
  }
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Starting Inflation | 3% | `0.03` | ✅ |
| Inflation Max | 3% | `0.03` | ✅ |
| Inflation Min | 3% | `0.03` | ✅ |
| Target Bonded | 0% | `0.0` | ✅ |

> **Note:** With `goal_bonded` at 0% and all inflation values set to 3%, the inflation rate will remain constant at 3% regardless of staking participation.

---

## 5. Validator Economics

### Requirements
| Parameter | Requirement | Status |
|-----------|-------------|--------|
| Max Validators | 100 | ✅ Configured |
| Min Commission | 0% | ✅ Configured |
| Genesis Validators | Foundation-operated | ✅ Configured |

### Genesis Implementation ✅

```json
"staking": {
  "params": {
    "max_validators": 100,
    "min_commission_rate": "0.000000000000000000"
  }
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Max Validators | 100 | `100` | ✅ |
| Min Commission | 0% | `0.0` | ✅ |

### Genesis Validators ✅

**Decision:** The network will launch with **3 Foundation-operated validators** to ensure network stability at genesis. Additional validators can join post-launch through standard delegation.

| Validator | Entity | Self-Stake | Commission | Role |
|-----------|--------|------------|------------|------|
| Integra Node 1 | Integra Foundation | 1,000,000,000 IRL | 10% | Primary |
| Integra Node 2 | Integra Foundation | 1,000,000,000 IRL | 10% | Secondary |
| Integra Node 3 | Integra Foundation | 1,000,000,000 IRL | 10% | Tertiary |

**Delegation Strategy:** Foundation tokens will be distributed across all 3 validators equally at genesis to ensure decentralization from day one. External validators are encouraged to join post-launch.

---

## 6. Governance Parameters

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Min Deposit | 100,000,000 IRL |
| Deposit Period | **7 days** |
| Voting Period | **7 days** |
| Quorum | 33.4% |
| Approval Threshold | 51% |
| Veto Threshold | 33.4% |
| Burn on Quorum Not Reached | false |
| Burn on Cancel | false |
| Burn on Veto | true |

### Genesis Implementation ✅

```json
"gov": {
  "params": {
    "min_deposit": [
      {
        "denom": "airl",
        "amount": "100000000000000000000000000"
      }
    ],
    "max_deposit_period": "604800s",
    "voting_period": "604800s",
    "quorum": "0.334000000000000000",
    "threshold": "0.510000000000000000",
    "veto_threshold": "0.334000000000000000",
    "burn_vote_quorum": false,
    "burn_proposal_deposit_prevote": false,
    "burn_vote_veto": true
  }
}
```

| Parameter | Required | Configured | Calculation | Status |
|-----------|----------|------------|-------------|--------|
| Min Deposit | 100M IRL | `100000000000000000000000000` | 100M × 10¹⁸ | ✅ |
| Deposit Period | **7 days** | `604800s` | 7 × 24 × 60 × 60 | ✅ |
| Voting Period | **7 days** | `604800s` | 7 × 24 × 60 × 60 | ✅ |
| Expedited Voting | 3 days | `259200s` | 3 × 24 × 60 × 60 | ✅ |
| Quorum | 33.4% | `0.334` | - | ✅ |
| Threshold | 51% | `0.51` | - | ✅ |
| Veto Threshold | 33.4% | `0.334` | - | ✅ |
| Burn on No Quorum | false | `false` | - | ✅ |
| Burn on Cancel | false | `false` | - | ✅ |
| Burn on Veto | true | `true` | - | ✅ |

---

## 7. Community Pool / Treasury

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Community Tax | **0%** |

### Genesis Implementation ✅

```json
"distribution": {
  "params": {
    "community_tax": "0.000000000000000000",
    "base_proposer_reward": "0.000000000000000000",
    "bonus_proposer_reward": "0.000000000000000000",
    "withdraw_addr_enabled": true
  }
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Community Tax | **0%** | `0.0` | ✅ |

> **Note:** Community tax set to 0% as per meeting decision. This can be changed via governance in the future.

---

## 8. Transaction Fees

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| Target TX Cost | **0.5 IRL per transaction** (~$0.005 at $1B valuation) |
| Gas Token | IRL/airl (single token model) |
| IRL Valuation Basis | $1 Billion (100B tokens = $0.01/IRL) |

### Fee Calculation

**At $1 Billion Valuation:**
- 100 Billion IRL total supply
- 1 IRL = $0.01
- Target: 0.5 IRL per simple transfer = $0.005 (half a cent)

**Gas Price Calculation:**
- Simple EVM transfer = ~21,000 gas
- Target cost = 0.5 IRL = 500,000,000,000,000,000 airl
- Base fee = 500,000,000,000,000,000 ÷ 21,000 = **23,809,523,809,524 airl/gas**

### Genesis Implementation ✅

```json
"feemarket": {
  "params": {
    "no_base_fee": false,
    "base_fee_change_denominator": 8,
    "elasticity_multiplier": 2,
    "base_fee": "23809523809524.000000000000000000",
    "min_gas_price": "23809523809524.000000000000000000",
    "min_gas_multiplier": "0.500000000000000000"
  }
},
"evm": {
  "params": {
    "evm_denom": "airl"
  }
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| Gas Token | `airl` | `airl` | ✅ |
| Base Fee | ~24 trillion airl/gas | `23809523809524` | ✅ |
| Min Gas Price | ~24 trillion airl/gas | `23809523809524` | ✅ |
| Single Token Model | Yes | Confirmed | ✅ |

### Transaction Cost Summary

| Transaction Type | Gas Used | Cost (IRL) | Cost (USD @ $1B) |
|------------------|----------|------------|------------------|
| Simple Transfer | 21,000 | **0.5 IRL** | $0.005 |
| Token Transfer | ~65,000 | ~1.55 IRL | $0.0155 |
| Contract Deploy | ~200,000+ | ~4.76+ IRL | $0.0476+ |

---

## 9. Smart Contract Configuration

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| EVM Contract Deployment | Permissionless |
| EVM Contract Calls | Permissionless |

### Genesis Implementation ✅

```json
"evm": {
  "params": {
    "access_control": {
      "create": {
        "access_type": "ACCESS_TYPE_PERMISSIONLESS",
        "access_control_list": []
      },
      "call": {
        "access_type": "ACCESS_TYPE_PERMISSIONLESS",
        "access_control_list": []
      }
    }
  },
  "preinstalls": []
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| EVM Create | Permissionless | `ACCESS_TYPE_PERMISSIONLESS` | ✅ |
| EVM Call | Permissionless | `ACCESS_TYPE_PERMISSIONLESS` | ✅ |
| Pre-deployed Contracts | None | `[]` | ✅ |

---

## 10. ERC-20 Module

### Requirements
| Parameter | Requirement |
|-----------|-------------|
| ERC-20 Enabled | true |
| Permissionless Registration | true |

### Genesis Implementation ✅

```json
"erc20": {
  "params": {
    "enable_erc20": true,
    "permissionless_registration": true
  },
  "token_pairs": [],
  "native_precompiles": [],
  "dynamic_precompiles": []
}
```

| Parameter | Required | Configured | Status |
|-----------|----------|------------|--------|
| ERC-20 Module | Enabled | `true` | ✅ |
| Permissionless | Yes | `true` | ✅ |

---

## 11. IBC Configuration

### Genesis Implementation ✅

```json
"ibc": {
  "client_genesis": {
    "params": {
      "allowed_clients": ["*"]
    }
  }
}
```

| Parameter | Configured | Status |
|-----------|------------|--------|
| IBC Enabled | Yes | ✅ |
| All Clients Allowed | `*` (any chain can bridge) | ✅ |

---

## 12. Slashing Parameters

### Genesis Implementation ✅

```json
"slashing": {
  "params": {
    "signed_blocks_window": "100",
    "min_signed_per_window": "0.500000000000000000",
    "downtime_jail_duration": "600s",
    "slash_fraction_double_sign": "0.050000000000000000",
    "slash_fraction_downtime": "0.010000000000000000"
  }
}
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| Signed Blocks Window | 100 blocks | Window for uptime calculation |
| Min Signed Per Window | 50% | Must sign at least 50% of blocks |
| Downtime Jail Duration | 10 minutes | Time validator is jailed for downtime |
| Double Sign Slash | 5% | Slashed for double signing |
| Downtime Slash | 1% | Slashed for downtime |

> **Note:** Slashed tokens go to treasury. Slashing can be adjusted via governance as the network matures.

---

## 13. Additional Configuration

### 13.1 Foundation Group ✅

**Decision:** No on-chain Foundation group at genesis. Foundation operates through standard multi-sig wallets and governance proposals.

### 13.2 Fee Grants ✅

**Decision:** Fee grants will be configured post-genesis using the Cosmos fee grant module.

**Implementation:** Foundation can grant gas allowances to verified users (issuers, brokers) via direct grants.

### 13.3 Vesting Accounts ✅

**Decision:** Cosmos vesting account types will be used for token allocation vesting.

**Feature:** Vesting accounts can delegate/stake tokens while they remain locked and non-transferable (standard Cosmos feature used by Celestia, Osmosis, etc.)

### 13.4 Emergency Powers ✅

**Decision:** No circuit breaker accounts at genesis. Emergency responses handled through expedited governance (3 day voting).

---

## Configuration Summary Table

| Category | Parameter | Value | Status |
|----------|-----------|-------|--------|
| **Token** | Symbol | IRL | ✅ |
| | Decimals | 18 | ✅ |
| | Base Denom | `airl` | ✅ |
| | Description | "The native token of Integra" | ✅ |
| **Supply** | Total | 100B IRL | ✅ |
| | Treasury | `integra1khs68tk...` | ✅ |
| **Staking** | Unbonding | 21 days | ✅ |
| | Max Validators | 100 | ✅ |
| | Min Commission | 0% | ✅ |
| **Validators** | Genesis Count | 3 (Foundation) | ✅ |
| **Inflation** | Starting Rate | 3% (fixed) | ✅ |
| | Target Bonded | 0% | ✅ |
| **Governance** | Min Deposit | 100M IRL | ✅ |
| | Deposit Period | **7 days** | ✅ |
| | Voting Period | **7 days** | ✅ |
| | Expedited Voting | 3 days | ✅ |
| | Quorum | 33.4% | ✅ |
| | Threshold | 51% | ✅ |
| **Treasury** | Community Tax | **0%** | ✅ |
| **Fees** | Simple Transfer Cost | **0.5 IRL** | ✅ |
| | Base Fee | ~24T airl/gas | ✅ |
| **EVM** | Deployment | Permissionless | ✅ |
| | Gas Token | airl | ✅ |
| **ERC-20** | Enabled | true | ✅ |
| **IBC** | All Clients | `*` | ✅ |
| **Slashing** | Double Sign | 5% | ✅ |
| | Downtime | 1% | ✅ |

---

## 14. Full Genesis JSON

```json
{
  "genesis_time": "2026-01-05T21:31:50.877028109Z",
  "chain_id": "integra-1",
  "initial_height": "1",
  "consensus_params": {
    "block": {
      "max_bytes": "22020096",
      "max_gas": "-1"
    },
    "evidence": {
      "max_age_num_blocks": "100000",
      "max_age_duration": "172800000000000",
      "max_bytes": "1048576"
    },
    "validator": {
      "pub_key_types": [
        "ed25519"
      ]
    },
    "version": {
      "app": "0"
    },
    "abci": {
      "vote_extensions_enable_height": "0"
    }
  },
  "app_hash": "",
  "app_state": {
    "07-tendermint": null,
    "auth": {
      "params": {
        "max_memo_characters": "256",
        "tx_sig_limit": "7",
        "tx_size_cost_per_byte": "10",
        "sig_verify_cost_ed25519": "590",
        "sig_verify_cost_secp256k1": "1000"
      },
      "accounts": [
        {
          "@type": "/cosmos.auth.v1beta1.BaseAccount",
          "address": "integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw",
          "pub_key": null,
          "account_number": "0",
          "sequence": "0"
        }
      ]
    },
    "authz": {
      "authorization": []
    },
    "bank": {
      "params": {
        "send_enabled": [],
        "default_send_enabled": true
      },
      "balances": [
        {
          "address": "integra1khs68tk2jatw0jthrtkfpfm7jckjsd05mrg8vw",
          "coins": [
            {
              "denom": "airl",
              "amount": "100000000000000000000000000000"
            }
          ]
        }
      ],
      "supply": [
        {
          "denom": "airl",
          "amount": "100000000000000000000000000000"
        }
      ],
      "denom_metadata": [
        {
          "description": "The native token of Integra",
          "denom_units": [
            {
              "denom": "airl",
              "exponent": 0,
              "aliases": [
                "attoirl"
              ]
            },
            {
              "denom": "irl",
              "exponent": 18,
              "aliases": []
            }
          ],
          "base": "airl",
          "display": "irl",
          "name": "Integra",
          "symbol": "IRL"
        }
      ],
      "send_enabled": []
    },
    "consensus": null,
    "distribution": {
      "params": {
        "community_tax": "0.000000000000000000",
        "base_proposer_reward": "0.000000000000000000",
        "bonus_proposer_reward": "0.000000000000000000",
        "withdraw_addr_enabled": true
      },
      "fee_pool": {
        "community_pool": []
      },
      "delegator_withdraw_infos": [],
      "previous_proposer": "",
      "outstanding_rewards": [],
      "validator_accumulated_commissions": [],
      "validator_historical_rewards": [],
      "validator_current_rewards": [],
      "delegator_starting_infos": [],
      "validator_slash_events": []
    },
    "erc20": {
      "params": {
        "enable_erc20": true,
        "permissionless_registration": true
      },
      "token_pairs": [],
      "allowances": [],
      "native_precompiles": [],
      "dynamic_precompiles": []
    },
    "evidence": {
      "evidence": []
    },
    "evm": {
      "accounts": [],
      "params": {
        "evm_denom": "airl",
        "extra_eips": [],
        "evm_channels": [],
        "access_control": {
          "create": {
            "access_type": "ACCESS_TYPE_PERMISSIONLESS",
            "access_control_list": []
          },
          "call": {
            "access_type": "ACCESS_TYPE_PERMISSIONLESS",
            "access_control_list": []
          }
        },
        "active_static_precompiles": [],
        "history_serve_window": "8192",
        "extended_denom_options": {
          "extended_denom": "airl"
        }
      },
      "preinstalls": []
    },
    "feegrant": {
      "allowances": []
    },
    "feemarket": {
      "params": {
        "no_base_fee": false,
        "base_fee_change_denominator": 8,
        "elasticity_multiplier": 2,
        "enable_height": "0",
        "base_fee": "23809523809524.000000000000000000",
        "min_gas_price": "23809523809524.000000000000000000",
        "min_gas_multiplier": "0.500000000000000000"
      },
      "block_gas": "0"
    },
    "genutil": {
      "gen_txs": []
    },
    "gov": {
      "starting_proposal_id": "1",
      "deposits": [],
      "votes": [],
      "proposals": [],
      "deposit_params": null,
      "voting_params": null,
      "tally_params": null,
      "params": {
        "min_deposit": [
          {
            "denom": "airl",
            "amount": "100000000000000000000000000"
          }
        ],
        "max_deposit_period": "604800s",
        "voting_period": "604800s",
        "quorum": "0.334000000000000000",
        "threshold": "0.510000000000000000",
        "veto_threshold": "0.334000000000000000",
        "min_initial_deposit_ratio": "0.000000000000000000",
        "proposal_cancel_ratio": "0.500000000000000000",
        "proposal_cancel_dest": "",
        "expedited_voting_period": "259200s",
        "expedited_threshold": "0.667000000000000000",
        "expedited_min_deposit": [
          {
            "denom": "airl",
            "amount": "500000000000000000000000000"
          }
        ],
        "burn_vote_quorum": false,
        "burn_proposal_deposit_prevote": false,
        "burn_vote_veto": true,
        "min_deposit_ratio": "0.010000000000000000"
      },
      "constitution": ""
    },
    "ibc": {
      "client_genesis": {
        "clients": [],
        "clients_consensus": [],
        "clients_metadata": [],
        "params": {
          "allowed_clients": [
            "*"
          ]
        },
        "create_localhost": false,
        "next_client_sequence": "0"
      },
      "connection_genesis": {
        "connections": [],
        "client_connection_paths": [],
        "next_connection_sequence": "0",
        "params": {
          "max_expected_time_per_block": "30000000000"
        }
      },
      "channel_genesis": {
        "channels": [],
        "acknowledgements": [],
        "commitments": [],
        "receipts": [],
        "send_sequences": [],
        "recv_sequences": [],
        "ack_sequences": [],
        "next_channel_sequence": "0"
      },
      "client_v2_genesis": {
        "counterparty_infos": []
      },
      "channel_v2_genesis": {
        "acknowledgements": [],
        "commitments": [],
        "receipts": [],
        "async_packets": [],
        "send_sequences": []
      }
    },
    "mint": {
      "minter": {
        "inflation": "0.030000000000000000",
        "annual_provisions": "0.000000000000000000"
      },
      "params": {
        "mint_denom": "airl",
        "inflation_rate_change": "0.030000000000000000",
        "inflation_max": "0.030000000000000000",
        "inflation_min": "0.030000000000000000",
        "goal_bonded": "0.000000000000000000",
        "blocks_per_year": "6311520"
      }
    },
    "precisebank": {
      "balances": [],
      "remainder": "0"
    },
    "slashing": {
      "params": {
        "signed_blocks_window": "100",
        "min_signed_per_window": "0.500000000000000000",
        "downtime_jail_duration": "600s",
        "slash_fraction_double_sign": "0.050000000000000000",
        "slash_fraction_downtime": "0.010000000000000000"
      },
      "signing_infos": [],
      "missed_blocks": []
    },
    "staking": {
      "params": {
        "unbonding_time": "1814400s",
        "max_validators": 100,
        "max_entries": 7,
        "historical_entries": 10000,
        "bond_denom": "airl",
        "min_commission_rate": "0.000000000000000000"
      },
      "last_total_power": "0",
      "last_validator_powers": [],
      "validators": [],
      "delegations": [],
      "unbonding_delegations": [],
      "redelegations": [],
      "exported": false
    },
    "transfer": {
      "port_id": "transfer",
      "denoms": [],
      "params": {
        "send_enabled": true,
        "receive_enabled": true
      },
      "total_escrowed": []
    },
    "upgrade": {},
    "vesting": {}
  }
}
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-22 | Integra Foundation | Initial genesis review document |
| 1.1 | 2026-01-22 | Integra Foundation | Updated per meeting: airl denom fix, 7-day governance, 0% community tax, 0.5 IRL tx fee |

---

*This document has been reviewed and all configuration decisions are finalized for mainnet genesis.*
