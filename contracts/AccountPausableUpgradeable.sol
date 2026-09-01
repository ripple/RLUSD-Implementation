// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/ContextUpgradeable.sol";

/**
 * @dev Halt activity for individual accounts that have been paused via `_pauseAccount` or
 * `_tryPauseAccount`; the same action can be reverted with `_unpauseAccount`. State is stored at a
 * custom storage location as per ERC-7201. Derived contracts such as `StablecoinUpgradeable` apply
 * the modifiers here to block actions for specific accounts.
 *
 * @custom:security-contact bugs@ripple.com
 */
abstract contract AccountPausableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:storage.AccountPausable
    struct AccountPausableStorage {
        mapping(address account => bool) _frozen;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.AccountPausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccountPausableStorageLocation = 0x345cc2404af916c3db112e7a6103770647a90ed78a5d681e21dc2e1174232900;

    function _getAccountPausableStorage() private pure returns (AccountPausableStorage storage $) {
        assembly {
            $.slot := AccountPausableStorageLocation
        }
    }

    /**
     * @dev Emitted when an account is paused in the contract.
     * @param account The account that was paused.
     */
    event AccountPaused(address indexed account);
    /**
     * @dev Emitted when an account is unpaused in the contract.
     * @param account The account that was unpaused.
     */
    event AccountUnpaused(address indexed account);

    error AccountIsPaused(address account);
    error AccountIsNotPaused(address account);

    function __AccountPausable_init() internal onlyInitializing {
        __AccountPausable_init_unchained();
    }

    function __AccountPausable_init_unchained() internal onlyInitializing {
    }

    /**
     * @dev Modifier to make a function callable only when the account is not paused.
     *
     * Requirements:
     * - The account must not already be paused.
     */
    modifier whenAccountNotPaused(address account) {
        require(!accountPaused(account), AccountIsPaused(account));
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the account is paused.
     *
     * Requirements:
     * - The account must already be paused.
     */
    modifier whenAccountPaused(address account) {
        require(accountPaused(account), AccountIsNotPaused(account));
        _;
    }

    /**
     * @notice Check if an address is paused in the contract.
     *
     * @param account The `address` to check the pause status of.
     *
     * @return Boolean to indicate if an account is paused or not.
     */
    function accountPaused(address account) public view virtual returns (bool) {
        AccountPausableStorage storage $ = _getAccountPausableStorage();
        return $._frozen[account];
    }

    /**
     * @dev Pauses an account from circulating the ERC20 token.
     *
     * Requirements:
     * - The account must not be paused.
     */
    function _pauseAccount(address account) internal virtual whenAccountNotPaused(account) {
        AccountPausableStorage storage $ = _getAccountPausableStorage();
        $._frozen[account] = true;
        emit AccountPaused(account);
    }

    /**
     * @dev Pauses an account from circulating the ERC20 token. And if the account is already paused, we don't revert.
     */
    function _tryPauseAccount(address account) internal virtual {
        AccountPausableStorage storage $ = _getAccountPausableStorage();
        if (!$._frozen[account]) {
            $._frozen[account] = true;
            emit AccountPaused(account);
        }
    }

    /**
     * @dev Returns account to normal state.
     *
     * Requirements:
     * - The account must be paused.
     */
    function _unpauseAccount(address account) internal virtual whenAccountPaused(account) {
        AccountPausableStorage storage $ = _getAccountPausableStorage();
        $._frozen[account] = false;
        emit AccountUnpaused(account);
    }
}
