# ICO Token Launchpad

A smart contract suite for launching and managing ICOs (Initial Coin Offerings) with built-in vesting, bonus logic, and upgradability via proxy pattern.

## Contract
- [telegram](http://t.me/caterpillardev)
- [twitter](http://x.com/caterpillardev)

## Features
- Create and manage multiple ICOs
- Flexible token sale parameters (price, amount, dates, bonus)
- Built-in vesting for purchased tokens
- TransparentUpgradeableProxy for contract upgrades
- Designed for integration with dApps and UIs

## Architecture
- **Launchpad.sol**: Main contract for ICO creation, token sales, vesting, and bonus logic.
- **VestingImplementation.sol**: Handles token vesting schedules and claims for beneficiaries.
- **TransparentUpgradeableProxy.sol**: OpenZeppelin-based proxy for upgradable contracts.


## Main Functions
- `createICO(ICOParams memory params)`: Start a new ICO
- `buyToken(uint256 id, uint256 amountToBuy, address buyer)`: Buy tokens from an ICO
- `closeICO(uint256 id)`: Close an ICO and reclaim unsold tokens
- `getICO(uint256 id)`: View ICO parameters and state
- `getValue(uint256 id, uint256 amount)`: Calculate payment required for token purchase

### Vesting Contract
- `allocateTokens(address to, uint256 amount, ...)`: Allocate tokens with vesting
- `claim() / claimBehalf(address)`: Claim unlocked tokens
- `getUnlockedAmount(address)`: View claimable and locked tokens

## Example Usage
1. **Create ICO**: Call `createICO` with desired parameters (ensure tokens are approved for transfer)
2. **Buy Tokens**: Call `buyToken` (ensure payment tokens are approved)
3. **Claim Vested Tokens**: Use `claim` or `claimBehalf` on the vesting contract


## Contributing
Pull requests and issues are welcome! Please open an issue to discuss your proposal before submitting a PR.

## License
No License (None)

