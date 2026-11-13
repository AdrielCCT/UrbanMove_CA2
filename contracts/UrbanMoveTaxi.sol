// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title  UrbanMoveTaxi
 * @notice This contract provides an escrow prototype for taxi booking and fare release. The system is designed to facilitate transactions between a passenger and a verified driver for UrbanMove Taxi Services.
 * @dev    The system is built with a Privacy by Design architecture because no names, phone numbers, or GPS coordinates are stored on the blockchain. A keccak256 hash of the journey details is recorded on the ledger. The real data is stored in the off-chain GDPR-compliant database of UrbanMove.
 */
contract UrbanMoveTaxi {
    // ---------------------------------------------------------------- types

    /**
     * This enum defines the status of the booking process.
     */
    enum Status {
        Requested,       // 0 - The passenger payment is held in the escrow.
        Accepted,        // 1 - The ride is accepted by a verified driver.
        InProgress,      // 2 - The journey is started.
        DriverCompleted, // 3 - The journey is marked as finished by the driver.
        Paid,            // 4 - The fare is released to the driver.
        Cancelled        // 5 - The booking is cancelled and the refund is processed.
    }

    struct Booking {
        address payable passenger;
        address payable driver;
        uint256 fare;            // The wei value is held in the escrow.
        bytes32 journeyHash;     // The hash of the off-chain journey data is stored.
        uint64  completedAt;     // The timestamp is recorded when the driver flags completion.
        Status  status;
    }

    // -------------------------------------------------------------- storage
    address public immutable admin;                  // The UrbanMove operator address is stored.
    uint256 public constant CANCEL_FEE_PERCENT = 10; // A fee is applied for late cancellations.
    uint256 public constant CONFIRMATION_WINDOW = 1 hours;

    uint256 public bookingCount;
    mapping(uint256 => Booking) private bookings;
    mapping(address => bool) public verifiedDrivers;

    // --------------------------------------------------------------- events
    event DriverVerified(address indexed driver);
    event DriverRevoked(address indexed driver);
    event RideRequested(uint256 indexed bookingId, address indexed passenger, address indexed driver, uint256 fare, bytes32 journeyHash);
    event RideAccepted(uint256 indexed bookingId, address indexed driver);
    event RideStarted(uint256 indexed bookingId);
    event RideCompleted(uint256 indexed bookingId, uint64 completedAt);
    event PaymentReleased(uint256 indexed bookingId, address indexed driver, uint256 amount);
    event RideCancelled(uint256 indexed bookingId, address indexed cancelledBy, uint256 refundToPassenger, uint256 feeToDriver);

    // ------------------------------------------------------------ modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only UrbanMove admin");
        _;
    }

    modifier bookingExists(uint256 id) {
        require(id > 0 && id <= bookingCount, "Booking does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ------------------------------------------------- driver verification

    /**
     * This function is used to verify a driver. The status is updated by the admin.
     */
    function verifyDriver(address driver) external onlyAdmin {
        require(driver != address(0), "Invalid address");
        verifiedDrivers[driver] = true;
        emit DriverVerified(driver);
    }

    /**
     * This function is used to revoke a driver. The verification is removed by the admin.
     */
    function revokeDriver(address driver) external onlyAdmin {
        verifiedDrivers[driver] = false;
        emit DriverRevoked(driver);
    }
}