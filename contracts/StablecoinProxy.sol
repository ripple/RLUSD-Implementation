// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC1967Proxy} from "node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Proxy to interact with {StablecoinUpgradeable}.
 *
 * @custom:security-contact bugs@ripple.com
 **/
contract StablecoinProxy is ERC1967Proxy {

    /**
     * @param implementation Address of the logic contract.
     * @param _data Optional initialization calldata forwarded to the implementation.
     */
    constructor (address implementation, bytes memory _data)  ERC1967Proxy(implementation, _data)  {
    }

    // No own functions: every selector is delegated so future implementations are never shadowed.
    // Read the implementation off-chain via the ERC-1967 slot (eth_getStorageAt) or on-chain via
    // ERC1967Utils.getImplementation().
}
