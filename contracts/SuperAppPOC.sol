//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperAppBase } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import { CFAv1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

contract SuperAppPOC is SuperAppBase {
    // by default, all 6 callbacks defined in the ISuperApp interface
    // are forwarded to a SuperApp.
    // If you inherit from SuperAppBase, there's a default implementation
    // for each callback which will revert.
    // Developers will want to avoid reverting in Super App callbacks, 
    // _NOOP flag for those
    // callbacks which you don't need and didn't implement.

    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;      
    bytes32 constant public CFA_ID = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    ISuperToken private _acceptedToken;
    address public _receiver;  

    constructor(
        ISuperfluid host,
        ISuperToken acceptedToken,
        address receiver
    ) {
        assert(address(host) != address(0));
        assert(address(acceptedToken) != address(0));
        assert(address(receiver) != address(0));

        _acceptedToken = acceptedToken;
        _receiver = receiver;

        cfaV1 = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(host.getAgreementClass(CFA_ID))
            )
        );

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;


        // Enables your Super App to be registered within the Superfluid host contract's Super App manifest. Allows it to be managed under basic Superfluid governance parameters and ensure that callbacks are run as intended.
        // You can register freely on testnets, but on mainnets you'll need to add a registration key. Contact the development team in the #developers channel on Discord to obtain a key.
        host.registerApp(configWord);
    }

    function _updateOutFlow(bytes calldata ctx) private returns (bytes memory newCtx) {
        newCtx = ctx;
        // @dev This will give me the new flowRate, as it is called in after callbacks
        int96 netFlowRate = cfaV1.cfa.getNetFlow(_acceptedToken, address(this));
        (, int96 outFlowRate, , ) = cfaV1.cfa.getFlow(
            _acceptedToken,
            address(this),
            _receiver
        ); // CHECK: unclear what happens if flow doesn't exist.
        int96 inFlowRate = netFlowRate + outFlowRate;

        // @dev If inFlowRate === 0, then delete existing flow.
        if (inFlowRate == int96(0)) {
            // @dev if inFlowRate is zero, delete outflow.
            newCtx = cfaV1.deleteFlowWithCtx(
                newCtx,
                address(this),
                _receiver,
                _acceptedToken
            );
        } else if (outFlowRate != int96(0)) {
            newCtx = cfaV1.updateFlowWithCtx(
                newCtx,
                _receiver,
                _acceptedToken,
                inFlowRate
            );
        } else {
            // @dev If there is no existing outflow, then create new flow to equal inflow
            newCtx = cfaV1.createFlowWithCtx(
                newCtx,
                _receiver,
                _acceptedToken,
                inFlowRate
            );
        }
    }

    // Super App callbacks are run when a Super App is on the receiving end of a transaction that creates, updates, or deletes a stream in relation to that app.
    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function afterAgreementCreated(
        // the protocol will pass the Super Token that's being used in the call to the constant flow agreement contract here.
        ISuperToken _superToken,
        // this will be the address of the Constant Flow Agreement contract on the network you're interacting with.
        address _agreementClass,
        // a bytes32 value that is a hash of the sender and receiver's address of the flow that was created, updated, or deleted
        bytes32, //_agreementId
        // the address of the sender and receiver of the flow that was created, updated, or deleted - encoded using solidity's abi.encode()
        bytes calldata, //_agreementData
        // this contains data that was returned by the beforeAgreement callback if it was run prior to the calling of afterAgreement callback
        bytes calldata, //_cbdata
        // this contains data about the call to the constant flow agreement contract itself. (Context)
        bytes calldata _ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        return _updateOutFlow(_ctx);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, // _agreementData,
        bytes calldata, // _cbdata,
        bytes calldata _ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        return _updateOutFlow(_ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, // _agreementData
        bytes calldata, // _cbdata,
        bytes calldata _ctx
    ) external override onlyHost returns (bytes memory newCtx) {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass))
            return _ctx;
        return _updateOutFlow(_ctx);

        // Use try catch for afterAgreementTerminated implementations that call another contract?
        // There is a limit of gas limit send in a callback function (3000000 gas units)
        // so don't create Super Apps that require too much gas within the termination callback.
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    modifier onlyHost() {
        require(
            msg.sender == address(cfaV1.host),
            "RedirectAll: support only one host"
        );
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }
}


