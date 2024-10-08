// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorMock.sol";

contract VRFCoordinator is VRFCoordinatorMock {
    constructor(address linkAddress) VRFCoordinatorMock(linkAddress){}
}