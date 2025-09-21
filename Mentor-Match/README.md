# Decentralized Tutoring Marketplace Smart Contract

## Overview

The Decentralized Tutoring Marketplace is a Stacks blockchain smart contract that enables peer-to-peer tutoring services. It provides a complete platform for tutors to offer their services and students to book tutoring sessions, with built-in escrow, rating systems, and dispute resolution mechanisms.

## Features

- **Tutor Registration**: Tutors can register with their subjects, hourly rates, and availability
- **Student Registration**: Students can create profiles to book sessions
- **Session Booking**: Secure booking system with escrow payments
- **Payment Processing**: Automated payment release after session completion
- **Rating System**: Bidirectional rating system for tutors and students
- **Dispute Resolution**: Built-in dispute mechanism with admin resolution
- **Platform Fees**: 2% platform fee on all transactions
- **Session Management**: Complete lifecycle management from booking to completion

## Contract Constants

### Platform Configuration
- `PLATFORM-FEE-BPS`: 200 (2% fee)
- `BASIS-POINTS`: 10000
- `CONTRACT-OWNER`: Contract deployer address

### Session Status
- `STATUS-PENDING`: 0 (Initial booking state)
- `STATUS-CONFIRMED`: 1 (Tutor confirmed)
- `STATUS-IN-PROGRESS`: 2 (Session started)
- `STATUS-COMPLETED`: 3 (Session finished)
- `STATUS-CANCELLED`: 4 (Session cancelled)
- `STATUS-DISPUTED`: 5 (Dispute raised)

### Rating Constants
- `MIN-RATING`: 1
- `MAX-RATING`: 5

## Data Structures

### Tutor Profile
```clarity
{
    name: (string-ascii 50),
    subjects: (list 10 (string-ascii 30)),
    hourly-rate: uint,
    rating: uint,
    total-ratings: uint,
    total-earnings: uint,
    is-active: bool,
    joined-at: uint
}
```

### Student Profile
```clarity
{
    name: (string-ascii 50),
    total-sessions: uint,
    total-spent: uint,
    joined-at: uint
}
```

### Session
```clarity
{
    session-id: uint,
    tutor: principal,
    student: principal,
    subject: (string-ascii 30),
    start-time: uint,
    duration-hours: uint,
    hourly-rate: uint,
    total-amount: uint,
    status: uint,
    created-at: uint,
    completed-at: (optional uint)
}
```

## Public Functions

### Registration Functions

#### `register-tutor`
Registers a new tutor on the platform.

**Parameters:**
- `name` (string-ascii 50): Tutor's name
- `subjects` (list 10 (string-ascii 30)): List of subjects taught
- `hourly-rate` (uint): Hourly rate in microSTX

**Requirements:**
- Hourly rate must be greater than 0
- Must provide at least one subject
- Cannot be already registered

#### `register-student`
Registers a new student on the platform.

**Parameters:**
- `name` (string-ascii 50): Student's name

**Requirements:**
- Cannot be already registered

### Session Management Functions

#### `book-session`
Books a tutoring session with payment held in escrow.

**Parameters:**
- `tutor` (principal): Tutor's address
- `subject` (string-ascii 30): Subject to be taught
- `start-time` (uint): Session start time (block height)
- `duration-hours` (uint): Session duration in hours

**Requirements:**
- Duration must be greater than 0
- Start time must be in the future
- Tutor must be active
- Student must have sufficient STX balance

#### `confirm-session`
Tutor confirms a pending session.

**Parameters:**
- `session-id` (uint): Session identifier

**Requirements:**
- Only the assigned tutor can confirm
- Session must be in PENDING status

#### `start-session`
Marks a session as in progress.

**Parameters:**
- `session-id` (uint): Session identifier

**Requirements:**
- Only the assigned tutor can start
- Session must be in CONFIRMED status

#### `complete-session`
Marks a session as completed.

**Parameters:**
- `session-id` (uint): Session identifier

**Requirements:**
- Only the assigned tutor can complete
- Session must be in IN-PROGRESS status

#### `cancel-session`
Cancels a session and refunds the student.

**Parameters:**
- `session-id` (uint): Session identifier

**Requirements:**
- Only tutor or student can cancel
- Session must be PENDING or CONFIRMED
- Automatic refund to student

### Payment Functions

#### `release-payment`
Releases escrowed payment to tutor after session completion.

**Parameters:**
- `session-id` (uint): Session identifier

**Requirements:**
- Session must be COMPLETED
- Payment not already released
- Updates tutor earnings and student spending

### Rating Functions

#### `rate-session`
Rate a completed session.

**Parameters:**
- `session-id` (uint): Session identifier
- `rating` (uint): Rating from 1-5
- `comment` (string-ascii 200): Optional comment

**Requirements:**
- Session must be completed
- Rating must be between 1-5
- Only tutor or student can rate
- Updates tutor's average rating when student rates

### Dispute Functions

#### `raise-dispute`
Raises a dispute for a session.

**Parameters:**
- `session-id` (uint): Session identifier
- `reason` (string-ascii 200): Dispute reason

**Requirements:**
- Only tutor or student can raise dispute
- No existing dispute for the session
- Changes session status to DISPUTED

### Tutor Management Functions

#### `update-tutor-availability`
Updates tutor's availability status.

**Parameters:**
- `is-active` (bool): Availability status

**Requirements:**
- Only registered tutors can update

#### `update-hourly-rate`
Updates tutor's hourly rate.

**Parameters:**
- `new-rate` (uint): New hourly rate

**Requirements:**
- Only registered tutors can update
- Rate must be greater than 0

### Admin Functions

#### `resolve-dispute`
Resolves a dispute (admin only).

**Parameters:**
- `dispute-id` (uint): Dispute identifier
- `resolution` (string-ascii 200): Resolution description

**Requirements:**
- Only contract owner can resolve
- Updates dispute status to COMPLETED

#### `withdraw-platform-earnings`
Withdraws accumulated platform fees (admin only).

**Requirements:**
- Only contract owner can withdraw
- Must have earnings to withdraw

## Read-Only Functions

### Data Retrieval
- `get-tutor`: Retrieve tutor profile
- `get-student`: Retrieve student profile
- `get-session`: Retrieve session details
- `get-session-ratings`: Retrieve session ratings
- `get-dispute`: Retrieve dispute details

### System Information
- `get-session-counter`: Get current session ID counter
- `get-platform-earnings`: Get accumulated platform earnings
- `calculate-session-cost`: Calculate total session cost including fees

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-UNAUTHORIZED-ACCESS | Unauthorized access attempt |
| 101 | ERR-TUTOR-NOT-FOUND | Tutor not found |
| 102 | ERR-STUDENT-NOT-FOUND | Student not found |
| 103 | ERR-SESSION-NOT-FOUND | Session not found |
| 104 | ERR-INSUFFICIENT-BALANCE | Insufficient balance |
| 105 | ERR-INVALID-AMOUNT | Invalid amount |
| 106 | ERR-SESSION-ALREADY-EXISTS | Session already exists |
| 107 | ERR-INVALID-STATUS | Invalid status |
| 108 | ERR-PAYMENT-ALREADY-PROCESSED | Payment already processed |
| 109 | ERR-RATING-OUT-OF-RANGE | Rating out of range |
| 110 | ERR-CANNOT-RATE-SELF | Cannot rate self |
| 111 | ERR-SESSION-NOT-COMPLETED | Session not completed |
| 112 | ERR-DISPUTE-ALREADY-EXISTS | Dispute already exists |
| 113 | ERR-INVALID-TIME-SLOT | Invalid time slot |
| 114 | ERR-TUTOR-NOT-AVAILABLE | Tutor not available |
| 115 | ERR-ALREADY-REGISTERED | Already registered |

## Usage Examples

### Registering as a Tutor
```clarity
(contract-call? .tutoring-marketplace register-tutor 
    "Alice Smith" 
    (list "Mathematics" "Physics" "Chemistry") 
    u50000000) ;; 50 STX per hour
```

### Booking a Session
```clarity
(contract-call? .tutoring-marketplace book-session 
    'SP1ABC123... ;; tutor address
    "Mathematics" 
    u12345 ;; start time (block height)
    u2) ;; 2 hours duration
```

### Rating a Session
```clarity
(contract-call? .tutoring-marketplace rate-session 
    u1 ;; session ID
    u5 ;; 5-star rating
    "Excellent tutor, very knowledgeable!")
```

## Fee Structure

The platform charges a 2% fee on all transactions:
- **Platform Fee**: 2% (200 basis points)
- **Fee Calculation**: (Total Amount × 200) ÷ 10000
- **Payment Flow**: Student pays base cost + platform fee, tutor receives base cost

## Security Features

1. **Escrow System**: Payments are held in contract until session completion
2. **Access Controls**: Function-level authorization checks
3. **Status Validation**: Strict state machine for session lifecycle
4. **Input Validation**: All inputs are validated before processing
5. **Dispute Resolution**: Built-in mechanism for handling conflicts