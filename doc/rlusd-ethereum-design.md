# Ripple USD Ethereum Design

Ripple USD (RLUSD) is an [ERC-20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) compliant token. The ERC-20 design includes standard imported functions from [OpenZepplin](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20), and specific functions written by Ripple Engineers.

The OpenZepplin library was chosen because:

- OpenZepplin are renowned smart contract auditors and open-source contributors.

- The OpenZepplin contracts are built with security, upgradeability, and modularity in mind.

- OpenZepplin contracts are completely standard compliant.

The deployed smart contracts enable minting, burning, global and individual freezing, clawback, and future upgrades to the ERC-20 contract. Permissions are controlled by a central Role Admin account, which is managed by Ripple internally.

## Ripple USD ERC-20 token

The Ripple USD token provides the following _enhancements_ beyond the standard ERC-20 features:

- **Individual Freeze/Unfreeze**: A mechanism to _pause/unpause_ activity on an individual account. A frozen account cannot call the [transfer(to, value)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#IERC20-transfer-address-uint256-), [transferFrom(from, to, value)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#IERC20-transferFrom-address-address-uint256-), [allowance(owner, spender)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#IERC20-allowance-address-address-), and `approve(spender, value)` functions, and is unable to receive Ripple USD stablecoin.

- **Global Freeze/Unfreeze**: A safety measure that enacts a _pause/unpause_ on all accounts. When a global freeze is enabled, the [transfer(to, value)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#IERC20-transfer-address-uint256-), [transferFrom(from, to, value)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#IERC20-transferFrom-address-address-uint256-), [decreaseAllowance(spender, value)](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20-safeDecreaseAllowance-contract-IERC20-address-uint256-) and `approve(spender, value)` functions will fail for all accounts.

- **Clawback**: A forced `burn(value)` function, which does not require a signature from the owner of the account, and is instead signed for by the account with the `Clawbacker` role.

## On-Chain roles

Ripple USD supports a number of roles which control how accounts interact with the token on-chain:

- `Minter`: Gives an account the ability to issue stablecoin.

- `Burner`: Gives an account the ability to burn stablecoin.

- `Pauser`: Gives an account the ability to create an individual or global freeze/unfreeze.

- `Clawbacker`: Gives an account the ability to force burn stablecoin from any account.

- `Upgrader`: Gives an account the ability to point the proxy at a new ERC-20, effectively upgrading the contract.

## Issuing and destroying stablecoin

Ripple is the only entity given the ability to _mint_ and _burn_ Ripple USD stablecoin via the `Minter` and `Burner` roles.

Only Ripple's issuer account can call the `mint()` function to issue new stablecoin upon a _distribution request_ from an onboarded customer.

Multiple internal Ripple accounts can call the `burn()` function to ensure an efficient operational process. Users can submit a _redemption request_ to a Ripple owned redemption account. Once the request is received and processed, Ripple will burn the amount of stablecoin in the request.

This iterative process ensures Ripple USD is always fully collateralized.

## Multi-Signing

Security of internal accounts is incredibly important. For this reason, Ripple has chosen to use on-chain multi-signature safeguards for _all_ internal accounts. Since this is supported natively on the XRP Ledger, Ripple chose to expand this functionality to Ethereum by introducing a custom `MultiSign` contract.

The `MultiSign` contract requires the creation of a predetermined list of known signers (accounts). The contract verifies that the transaction bytes provided are signed by the correct accounts, and then forwards the request function to the ERC-20 contract to execute the transaction.

> [!IMPORTANT]
> This functionality is not required by any community developer, but provides assurance that only Ripple groups will be able to increase and decrease the amount of stablecoin in circulation.

## Events

Events are emitted when the state of the stablecoin contract changes.

- `SignersChanged(address, address[], uint8[], uint256)` : The event is emitted when the `setSigners` method on an account's `MultiSign` contract is called. The values here are the account `address` for which the signers were changed, signer addresses, their weights, and the quorum.

- `Transfer(address, address, uint256)`: Emitted when value is moved from one account to another.

- `Paused(address)`: Emitted when `pause()` is called, triggering a _Global Freeze_ with the address that called the method.

- `Unpaused(address)`: Emitted when `unpause()` is called, triggering a _Global Unfreeze_ with the address that called the method.

- `AccountPaused(address)`: Emitted when `pauseAccount(address)` is called. The `address` represents the account that was _frozen_.

- `AccountUnpaused(address)`: Emitted when `unpauseAccount(address)` is called. The `address` represents the account that was _unfrozen_.

## Upgrading the ERC-20 contract

The Ripple USD token uses the [UUPS proxy pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#transparent-vs-uups) to go from one implementation to another. This pattern suggests that the _proxy_ contract holds the ERC-20 implementation contract address and delegates all calls to it. The logic to control the upgrade itself is found in the ERC-20 implementation contract, and the ability to upgrade is given to accounts with the `Upgrader` role.

The [UUPSUpgradeable](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable) contract is a dependency of the ERC-20 contract which gives the token access to [upgradeToAndCall(newImplementation, data)](https://docs.openzeppelin.com/contracts/5.x/api/proxy#ERC1967Utils-upgradeToAndCall-address-bytes-). When an authorized address with the `Upgrader` role calls this function, Ripple can safely migrate over to the new implementation. Because the upgrade process has no impact on storage, the state of balances, current transactions, and granted roles is preserved.
