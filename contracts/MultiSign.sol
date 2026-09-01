// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ECDSA} from "node_modules/@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev This is an implementation of an on-chain multi-sign. On-chain multi-sign ensures that a quorum of signatures
 * needs to be submitted before the transaction is passed on to the ERC20 contract(in our case). To verify signatures
 * and hash data in a particular way, we use the EIP712.sol scheme: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md.
 *
 * @custom:security-contact bugs@ripple.com
 */
contract MultiSign {

    //keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")
    bytes32 constant public EIP712DOMAIN_TYPEHASH = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;

    //keccak256("MultiSignTransaction(address destination,bytes data,uint256 nonce,address executor,uint256 gasLimit)")
    bytes32 constant public MULTISIGN_TYPEHASH = 0xb8dc02dde922989f2f9c331431088d8b7e24696ed816c001c5b82192a1c91a8f;

    //randomly generated salt
    bytes32 constant public SALT = 0x55c2a1c584c6a7013cb797a4622f427c630274bf9e8d9ec26ab9015ddaabcb33;

    //keccak256("MultiSign")
    bytes32 constant public NAME_HASH = 0xa2743967920baf970a18574423a5e903484167f01ff6c1b931ebc9e87d7792b9;

    // keccak256("1")
    bytes32 constant public VERSION_HASH = 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6;

    bytes32 private immutable DOMAIN_SEPARATOR;

    /**
     * A state variable to store the total weight of all signatures required to successfully finish
     * execution of the `execute` method.
     */
    uint256 public quorum;
    /**
     * Every transaction submitted to this contract should have a nonce associated to it just like
     * any other EOA or Contract Account. This state variable holds that value.
     */
    uint256 public nonce;
    address[] private signersArr;
    mapping (address signer => bool) private isSigner;
    mapping (address signer => uint8 weight) private weights;

    /**
     * @dev Event emitted when the state of the contract changes.
     *
     * @param account The contract for which the signer information was updated, which is this.
     * @param signers The new array of signer address.
     * @param weights The new array of weights of the signers.
     * @param quorum  The cumulative weight of all signatures should exceed or match this value.
     */
    event SignersChanged(address indexed account, address[] signers, uint8[] weights, uint256 quorum);

    /**
     * @dev Event emitted when the destination contract is called with the provided calldata.
     *
     * @param destination The contract being called with the provided calldata.
     * @param data        The encoded bytes that will lead to execution of a method and change state of the destination
     *                    contract.
     * @param gasLimit    The maximum amount of gas that can be consumed by the destination contract to execute the
     *                    calldata.
     */
    event DestinationCalled(address indexed destination, bytes data, uint256 gasLimit);

    error SignerWeightLengthMismatch();
    error TooManySigners();
    error QuorumIsZero();
    error AddressesNotSorted();
    error QuorumExceedsWeightSum();
    error OnlySelf();
    error SignatureArrayLengthMismatch();
    error ExecutorMustBeSender();
    error SignaturesOutOfOrder();
    error RecoveredNotSigner();
    error InsufficientSignatureWeight();
    error DestinationNotContract();
    error DestinationCallFailed();

    /**
     * @dev Default constructor to initialize the MultiSign contract.
     * Signer addresses must be strictly ascending by address value (numeric order).
     * @param _signers Ordered signer addresses.
     * @param _weights Per-signer signature weights, parallel to `_signers`.
     * @param _quorum Cumulative weight required to execute.
     */
    constructor (address[] memory _signers, uint8[] memory _weights, uint256 _quorum) {
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            NAME_HASH,
            VERSION_HASH,
            block.chainid,
            address(this),
            SALT
        ));

        setSigners_(_signers, _weights, _quorum);
        emit SignersChanged(address(this), _signers, _weights, _quorum);
    }

    /**
     * @dev Returns the list of signer addresses in an array.
     * @return The current signer addresses.
     */
    function signers() external view returns (address[] memory) {
        return signersArr;
    }

    /**
     * @dev Given an address of a signer, return the weight of its signature that gets counted
     * for this account.
     * @param signer The signer address to query.
     * @return The weight of `signer`, or 0 if not a signer.
     */
    function signerWeight(address signer) external view returns (uint8) {
        return weights[signer];
    }

    // Note that signers_ must be strictly increasing, in order to prevent duplicates
    function setSigners_(address[] memory _signers, uint8[] memory _weights, uint256 _quorum) private {
        require(_signers.length == _weights.length, SignerWeightLengthMismatch());
        require(_signers.length <= 32, TooManySigners());
        require(_quorum > 0, QuorumIsZero());

        // remove old signers from map and set weights to 0
        uint256 existingSignerArrLength = signersArr.length;
        for (uint256 i = 0; i < existingSignerArrLength; ++i) {
            isSigner[signersArr[i]] = false;
            weights[signersArr[i]] = 0;
        }

        // add new signers to map
        uint256 signatureWeights;
        address lastAdd;
        uint256 newSignerArrLength = _signers.length;
        for (uint256 i = 0; i < newSignerArrLength; ++i) {
            require(_signers[i] > lastAdd, AddressesNotSorted());
            isSigner[_signers[i]] = true;
            weights[_signers[i]] = _weights[i];
            signatureWeights += _weights[i];
            lastAdd = _signers[i];
        }
        require(_quorum <= signatureWeights, QuorumExceedsWeightSum());

        // set signers array and quorum
        signersArr = _signers;
        quorum = _quorum;
    }

    /**
     * @dev This method facilitates changing the signer addresses, their weights and quorum. Since
     * this method changes the state of the contract, it emits the `SignersChanged` event at the
     * end of successful execution.
     * This method can be called by this contract only in order to verify that the signatures are
     * from existing signers with privilege to do so.
     * @param _signers Ordered signer addresses.
     * @param _weights Per-signer signature weights, parallel to `_signers`.
     * @param _quorum Cumulative weight required to execute.
     */
    function setSigners(address[] memory _signers, uint8[] memory _weights, uint256 _quorum) external {
        require(msg.sender == address(this), OnlySelf());
        setSigners_(_signers, _weights, _quorum);
        emit SignersChanged(address(this), _signers, _weights, _quorum);
    }

    /**
     * @dev This method is called by an EOA/funding account with the correct set of signatures to eventually
     * make a call to the `destination` with provided call data.
     * Example, calls to the ERC20 contract are made from this method for all MultiSign accounts.
     * @param sigV Signature v components, ordered by recovered signer address.
     * @param sigR Signature r components, parallel to `sigV`.
     * @param sigS Signature s components, parallel to `sigV`.
     * @param executor Address that must equal `msg.sender`.
     * @param destination Contract that receives the call.
     * @param gasLimit Gas stipend forwarded to `destination`.
     * @param data Calldata executed against `destination`.
     */
    function execute(
        uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS, address executor, address destination,
        uint256 gasLimit, bytes calldata data
    ) external {

        require(sigR.length == sigS.length && sigR.length == sigV.length, SignatureArrayLengthMismatch());
        require(executor == msg.sender, ExecutorMustBeSender());

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                MULTISIGN_TYPEHASH,
                destination,
                keccak256(data),
                nonce,
                executor,
                gasLimit
            ))
        ));

        uint256 signatureWeights;
        address lastAdd; // cannot have address(0) as an owner (default)
        uint256 signaturesLength = sigV.length;
        for (uint256 i = 0; i < signaturesLength; ++i) {
            address recovered = ECDSA.recover(digest, sigV[i], sigR[i], sigS[i]);
            require(recovered > lastAdd, SignaturesOutOfOrder());
            require(isSigner[recovered], RecoveredNotSigner());
            lastAdd = recovered;
            signatureWeights += weights[recovered];
        }
        require(signatureWeights >= quorum, InsufficientSignatureWeight());

        // If we make it here all signatures are accounted for.
        nonce = nonce + 1;

        require(destination.code.length > 0, DestinationNotContract());

        (bool success,) = destination.call{gas: gasLimit}(data);
        emit DestinationCalled(destination, data, gasLimit);
        require(success, DestinationCallFailed());
    }
}
