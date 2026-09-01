// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {StablecoinUpgradeable} from "./StablecoinUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

/**
 * @custom:oz-upgrades-from StablecoinUpgradeable.sol
 * @title StablecoinUpgradeableV2
 * @dev This contract is an upgradeable ERC20 token that implements the ERC20Permit and ERC20Pausable interfaces.
 *
 * @custom:security-contact bugs@ripple.com
 */
contract StablecoinUpgradeableV2 is ERC20PermitUpgradeable, StablecoinUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier _onlyUninitialized() {
        if (_getInitializedVersion() != 0) {
            revert Initializable.InvalidInitialization();
        }
        _;
    }

    modifier _onlyInitializedV1() {
        if (_getInitializedVersion() != 1) {
            revert Initializable.InvalidInitialization();
        }
        _;
    }

    /**
     * @dev This method is used to re-initialize the contract with values that we want to use to bootstrap and run things.
     * The modifier reinitializer here helps us block initialization in the constructor so that we initialize value only
     * when deploying the proxy and not the contract itself. The reinitializer also tracks how many times this method is
     * called and it can only be called once.
     */
    function reinitialize() external _onlyInitializedV1 reinitializer(2) {
        __ERC20Permit_init(name());
    }

    /**
     * @dev This method is used to initialize the contract with values that we want to use to bootstrap and run things.
     * The modifier initializer here helps us block initialization in the constructor so that we initialize value only
     * when deploying the proxy and not the contract itself. The initializer also tracks how many times this method is
     * called and it can only be called once.
     *
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param minter_ The address of the minter role.
     * @param admin_ The address of the admin role.
     * @param upgrader_ The address of the upgrader role.
     * @param pauser_ The address of the pauser role.
     * @param clawbacker_ The address of the clawbacker role.
     */
    function initialize(string memory name_, string memory symbol_, address minter_, address admin_, address upgrader_,
            address pauser_, address clawbacker_)
        external virtual override _onlyUninitialized reinitializer(2)
    {
        _initializeV2Params(name_, symbol_, admin_, upgrader_, pauser_, clawbacker_);
        _grantRole(MINTER_ROLE, minter_);
    }

    function _initializeV2Params(string memory name_, string memory symbol_, address admin_, address upgrader_,
        address pauser_, address clawbacker_) internal onlyInitializing {
        __ERC20_init(name_, symbol_);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, upgrader_);
        __ERC20Pausable_init();
        __AccountPausable_init();
        _grantRole(PAUSER_ROLE, pauser_);
        _grantRole(CLAWBACKER_ROLE, clawbacker_);
        __ERC20Permit_init(name_);
    }

    /// @inheritdoc StablecoinUpgradeable
    function _update(address from, address to, uint256 value) internal virtual
        override(StablecoinUpgradeable, ERC20Upgradeable)
        whenAccountNotPaused(to)
        whenAccountNotPaused(_msgSender())
    {
        // Clawback burns (to == 0, caller is not the frozen account) skip the from-paused check.
        if (!(to == address(0) && from != _msgSender())) {
            require(!accountPaused(from), AccountIsPaused(from));
        }
        ERC20PausableUpgradeable._update(from, to, value);
    }

    // @inheritdoc StablecoinUpgradeable
    function pauseAccounts(address[] calldata accounts) public virtual
        override(StablecoinUpgradeable)
        onlyRole(PAUSER_ROLE)
    {
        address lastAdd = address(0);
        uint256 accountsLength = accounts.length;
        require(accountsLength > 0, "No accounts to pause");
        for (uint256 i = 0; i < accountsLength; ++i) {
            require(accounts[i] > lastAdd, "Addresses should be sorted");
            _tryPauseAccount(accounts[i]);
            lastAdd = accounts[i];
        }
    }

    /// @inheritdoc StablecoinUpgradeable
    function approve(address spender, uint256 value) public virtual
        override(StablecoinUpgradeable, ERC20Upgradeable)
        returns (bool)
    {
        return StablecoinUpgradeable.approve(spender, value);
    }

    /**
     * An overridden method to add modifiers to check if the accounts being used to transfer are not frozen.
     *
     * @param owner The address of the owner of the token.
     * @param spender The address of the spender of the token.
     * @param value The amount of tokens to be approved.
     * @param deadline The deadline for the permit.
     * @param v The v value of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     *
     * Requirements:
     * - the {owner} account should not be paused/frozen
     * - the {spender} account should not be paused/frozen
     * - the {msg.sender} account should not be paused/frozen
     * - this contract is not paused
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override(ERC20PermitUpgradeable)
        whenAccountNotPaused(owner)
        whenAccountNotPaused(spender)
        whenAccountNotPaused(_msgSender())
        whenNotPaused
    {
        super.permit(owner, spender, value, deadline, v, r, s);
    }
}
