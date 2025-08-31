// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {RegistryModuleOwnerCustom} from
    "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    address immutable owner = makeAddr("owner");
    address immutable user = makeAddr("user");
    uint256 SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setup() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createSelectFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 1. Deploy and configure on sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaPool)
        );
        vm.stopPrank();

        // 2. Deploy and configure on arb-sepolia
        vm.startPrank(owner);
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken)
        );
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );
        vm.startPrank(owner);
        vm.stopPrank();
    }

    function setupTokenPools() public {
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork, address(arbSepoliaPool), uint64(421613), address(sepoliaPool), address(sepoliaToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes memory remotePoolAddress = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        //         struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }

        bytes memory remoteTokenAddr = abi.encode(remoteTokenAddress);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: false,
            remotePoolAddress: remotePoolAddress,
            remoteTokenAddress: remoteTokenAddr,
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }

    function bridgeTokens(uint256 amountToBridge, uint256 localFork, uint256 remoteFork, Register.NetworkDetails memory localNetworkDetails, Register.NetworkDetails memory remoteNetworkDetails, RebaseToken localToken, RebaseToken remoteToken) public {
        vm.selectFork(localFork);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
             extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(localUserInterestRate, remoteUserInterestRate);
        

    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(SEND_VALUE, sepoliaFork, arbSepoliaFork, sepoliaNetworkDetails, arbSepoliaNetworkDetails, sepoliaToken, arbSepoliaToken);
    }

    vm.selectFork(arbSepoliaFork);
    vm.warp(block.timestamp + 20 minutes);
    bridgeTokens(arbSepoliaToken.balanceOf(user), arbSepoliaFork, sepoliaFork, arbSepoliaNetworkDetails, sepoliaNetworkDetails, arbSepoliaToken, sepoliaToken);
}
