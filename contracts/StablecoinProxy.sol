// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC1967Proxy} from "node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Proxy to interact with {StablecoinUpgradeable}.
 *
 * @custom:security-contact bugs@ripple.com
 **/
contract StablecoinProxy is ERC1967Proxy {

    constructor (address implementation, bytes memory _data)  ERC1967Proxy(implementation, _data)  {
    }

    /**
     * @dev Returns the implementation address of the contract that executes a transaction.
     */
    function getImplementation() public view returns (address) {
        return _implementation();
    }

}
