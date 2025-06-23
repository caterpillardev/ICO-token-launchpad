# ICO Token Launchpad Documentation

## Overview
ICO Token Launchpad is a smart contract suite for launching and managing ICOs (Initial Coin Offerings) with built-in vesting, bonus logic, and upgradability. It is designed for seamless integration with dApps and UIs, and supports flexible token sale and vesting parameters.

---

## Architecture

- **Launchpad.sol**: Main contract for ICO creation, token sales, vesting, and bonus logic.
- **VestingImplementation.sol**: Handles token vesting schedules and claims for beneficiaries.
- **TransparentUpgradeableProxy.sol**: OpenZeppelin-based proxy for upgradable contracts.

### High-Level Flow
1. **Admin deploys Launchpad via TransparentUpgradeableProxy**
2. **Project owner creates an ICO**
3. **Users buy tokens from the ICO**
4. **Purchased tokens are distributed (some immediately, some via vesting)**
5. **Users claim vested tokens over time**
6. **ICO owner can close the ICO and reclaim unsold tokens**

---

## Data Structures

### VestingParams
```
struct VestingParams {
    uint256 unlockPercentage; // % (2 decimals) initially unlocked
    uint256 cliffPeriod;      // Cliff period in seconds
    uint256 vestingPercentage;// % (2 decimals) unlocked per interval
    uint256 vestingInterval;  // Interval in seconds
}
```

### ICOParams
```
struct ICOParams {
    address token;
    address paymentToken; // address(0) = native coin
    uint256 amount;
    uint256 startPrice;
    uint256 endPrice; // 0 = fixed price
    uint256 startDate;
    uint256 endDate; // 0 = until all tokens sold
    uint256 bonusReserve;
    uint256 bonusPercentage;
    uint256 bonusActivator;
    VestingParams vestingParams;
}
```

### ICOState
```
struct ICOState {
    address ICOOwner;
    uint8 icoTokenDecimals;
    address vestingContract;
    bool isClosed;
    uint256 totalSold;
    uint256 totalReceived;
}
```

---

## Launchpad.sol Contract

### Key Functions
- `createICO(ICOParams memory params)`: Starts a new ICO. Tokens must be approved for transfer.
- `buyToken(uint256 id, uint256 amountToBuy, address buyer)`: Buy tokens from an ICO. Handles payment, bonus, and vesting.
- `closeICO(uint256 id)`: Close an ICO and reclaim unsold tokens.
- `getICO(uint256 id)`: Returns ICO parameters and state.
- `getValue(uint256 id, uint256 amount)`: Calculates payment required for a given token amount.
- `setPauseLaunchpad(bool pause)`: Pauses/unpauses the launchpad (owner only).
- `setVestingImplementation(address)`: Updates the vesting implementation (owner only).

### Events
- `ICOCreated(uint256 ICO_id, address token, address owner, address vestingContract)`
- `BuyToken(address buyer, uint256 ICO_id, uint256 amountPaid, uint256 amountBought, uint256 bonus)`
- `CloseICO(uint256 ICO_id, address owner, address token, uint256 refund)`

---

## VestingImplementation.sol Contract

### Key Functions
- `initialize(address owner_, address vestedToken_)`: Initializes the vesting contract.
- `allocateTokens(address to, uint256 amount, uint256 cliffFinish, uint256 vestingPercentage, uint256 vestingInterval)`: Allocates tokens to a beneficiary with a vesting schedule.
- `claim()`: Claims unlocked tokens for the caller.
- `claimBehalf(address beneficiary)`: Claims unlocked tokens for another beneficiary.
- `getUnlockedAmount(address beneficiary)`: Returns unlocked, locked, and next unlock time for a beneficiary.
- `setDepositor(address, bool)`: Grants/revokes depositor rights (owner only).
- `rescueTokens(address)`: Owner can rescue unallocated tokens.

### Events
- `SetDepositor(address depositor, bool enable)`
- `Claim(address indexed beneficiary, uint256 amount)`
- `AddAllocation(address indexed to, uint256 amount, uint256 cliffFinish, uint256 vestingPercentage, uint256 vestingInterval)`
- `Rescue(address _token, uint256 _amount)`

---

## TransparentUpgradeableProxy.sol
- Implements the transparent proxy pattern for upgradable contracts.
- Only the admin can upgrade the implementation or change the admin.
- All other calls are forwarded to the implementation contract.

---

## Example Flows

### 1. Creating an ICO
1. Project owner approves the Launchpad contract to transfer the required amount of tokens (including bonus reserve).
2. Calls `createICO` with desired parameters.
3. Event `ICOCreated` is emitted.

### 2. Buying Tokens
1. User approves payment tokens (if not using native coin).
2. Calls `buyToken` with ICO id, amount, and their address.
3. Tokens are distributed: some immediately, some via vesting contract.
4. Event `BuyToken` is emitted.

### 3. Claiming Vested Tokens
1. User calls `claim` on the vesting contract.
2. Unlocked tokens are transferred to the user.
3. Event `Claim` is emitted.

### 4. Closing an ICO
1. ICO owner calls `closeICO`.
2. Unsold tokens and remaining bonus reserve are returned to the owner.
3. Event `CloseICO` is emitted.

---

## Security & Upgradeability Notes
- **Proxy Pattern**: All user interactions should go through the proxy contract to ensure upgradability.
- **Ownership**: Only the contract owner can pause the launchpad, update vesting implementation, or rescue tokens.
- **Vesting**: Vesting logic ensures tokens are released over time, reducing risk of immediate dumps.
- **Testing**: Use the provided TokenFactory for creating test tokens.

---

## License
No License (None) 