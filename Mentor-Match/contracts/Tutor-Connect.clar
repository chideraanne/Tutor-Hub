;; Decentralized Tutoring Marketplace Smart Contract
;; This contract enables tutors to register their services and students to book sessions
;; Handles payments, escrow, ratings, and dispute resolution

;; Error constants 
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-TUTOR-NOT-FOUND (err u101))
(define-constant ERR-STUDENT-NOT-FOUND (err u102))
(define-constant ERR-SESSION-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-SESSION-ALREADY-EXISTS (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-PAYMENT-ALREADY-PROCESSED (err u108))
(define-constant ERR-RATING-OUT-OF-RANGE (err u109))
(define-constant ERR-CANNOT-RATE-SELF (err u110))
(define-constant ERR-SESSION-NOT-COMPLETED (err u111))
(define-constant ERR-DISPUTE-ALREADY-EXISTS (err u112))
(define-constant ERR-INVALID-TIME-SLOT (err u113))
(define-constant ERR-TUTOR-NOT-AVAILABLE (err u114))
(define-constant ERR-ALREADY-REGISTERED (err u115))
(define-constant ERR-INVALID-INPUT (err u116))

;; Contract owner for administrative functions
(define-constant CONTRACT-OWNER tx-sender)

;; Platform fee percentage (2% = 200 basis points)
(define-constant PLATFORM-FEE-BPS u200)
(define-constant BASIS-POINTS u10000)

;; Session status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-CONFIRMED u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)
(define-constant STATUS-DISPUTED u5)

;; Rating validation constants
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)

;; Input validation constants
(define-constant MIN-NAME-LENGTH u1)
(define-constant MAX-NAME-LENGTH u50)
(define-constant MIN-SUBJECT-LENGTH u1)
(define-constant MAX-SUBJECT-LENGTH u30)
(define-constant MIN-REASON-LENGTH u10)
(define-constant MAX-REASON-LENGTH u200)
(define-constant MIN-RESOLUTION-LENGTH u10)
(define-constant MAX-RESOLUTION-LENGTH u200)

;; Data structure for tutor profiles
(define-map tutors
    principal
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
)

;; Data structure for student profiles
(define-map students
    principal
    {
        name: (string-ascii 50),
        total-sessions: uint,
        total-spent: uint,
        joined-at: uint
    }
)

;; Data structure for tutoring sessions
(define-map sessions
    uint
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
)

;; Data structure for session ratings
(define-map session-ratings
    uint
    {
        tutor-rating: (optional uint),
        student-rating: (optional uint),
        tutor-comment: (optional (string-ascii 200)),
        student-comment: (optional (string-ascii 200))
    }
)

;; Data structure for disputes
(define-map disputes
    uint
    {
        session-id: uint,
        raised-by: principal,
        reason: (string-ascii 200),
        status: uint,
        resolved-at: (optional uint),
        resolution: (optional (string-ascii 200))
    }
)

;; Escrow for session payments
(define-map session-escrow
    uint
    {
        amount: uint,
        paid: bool,
        released: bool
    }
)

;; Counter for session IDs
(define-data-var session-counter uint u0)

;; Counter for dispute IDs  
(define-data-var dispute-counter uint u0)

;; Platform earnings accumulator
(define-data-var platform-earnings uint u0)

;; Helper function to validate string input
(define-private (is-valid-string (input (string-ascii 200)) (min-len uint) (max-len uint))
    (let ((input-len (len input)))
        (and (>= input-len min-len) (<= input-len max-len))
    )
)

;; Helper function to validate name
(define-private (is-valid-name (name (string-ascii 50)))
    (is-valid-string name MIN-NAME-LENGTH MAX-NAME-LENGTH)
)

;; Helper function to validate subject
(define-private (is-valid-subject (subject (string-ascii 30)))
    (is-valid-string subject MIN-SUBJECT-LENGTH MAX-SUBJECT-LENGTH)
)

;; Helper function to validate subjects list
(define-private (validate-subjects (subjects (list 10 (string-ascii 30))))
    (let ((subjects-len (len subjects)))
        (and 
            (> subjects-len u0)
            (<= subjects-len u10)
            (fold check-subject-validity subjects true)
        )
    )
)

;; Helper function for fold to check each subject
(define-private (check-subject-validity (subject (string-ascii 30)) (prev-valid bool))
    (and prev-valid (is-valid-subject subject))
)

;; Helper function to validate reason/resolution strings
(define-private (is-valid-reason (reason (string-ascii 200)))
    (is-valid-string reason MIN-REASON-LENGTH MAX-REASON-LENGTH)
)

;; Helper function to validate resolution strings
(define-private (is-valid-resolution (resolution (string-ascii 200)))
    (is-valid-string resolution MIN-RESOLUTION-LENGTH MAX-RESOLUTION-LENGTH)
)

;; Function to register as a tutor
(define-public (register-tutor (name (string-ascii 50)) (subjects (list 10 (string-ascii 30))) (hourly-rate uint))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-name name) ERR-INVALID-INPUT)
        (asserts! (validate-subjects subjects) ERR-INVALID-INPUT)
        (asserts! (> hourly-rate u0) ERR-INVALID-AMOUNT)
        
        ;; Check if already registered
        (asserts! (is-none (map-get? tutors tx-sender)) ERR-ALREADY-REGISTERED)
        
        ;; Register the tutor
        (map-set tutors tx-sender {
            name: name,
            subjects: subjects,
            hourly-rate: hourly-rate,
            rating: u0,
            total-ratings: u0,
            total-earnings: u0,
            is-active: true,
            joined-at: block-height
        })
        
        (ok true)
    )
)

;; Function to register as a student
(define-public (register-student (name (string-ascii 50)))
    (begin
        ;; Validate input
        (asserts! (is-valid-name name) ERR-INVALID-INPUT)
        
        ;; Check if already registered
        (asserts! (is-none (map-get? students tx-sender)) ERR-ALREADY-REGISTERED)
        
        ;; Register the student
        (map-set students tx-sender {
            name: name,
            total-sessions: u0,
            total-spent: u0,
            joined-at: block-height
        })
        
        (ok true)
    )
)

;; Function to book a tutoring session
(define-public (book-session (tutor principal) (subject (string-ascii 30)) (start-time uint) (duration-hours uint))
    (let (
        (session-id (+ (var-get session-counter) u1))
        (tutor-data (unwrap! (map-get? tutors tutor) ERR-TUTOR-NOT-FOUND))
        (student-data (unwrap! (map-get? students tx-sender) ERR-STUDENT-NOT-FOUND))
        (total-amount (* (get hourly-rate tutor-data) duration-hours))
        (platform-fee (/ (* total-amount PLATFORM-FEE-BPS) BASIS-POINTS))
        (total-with-fee (+ total-amount platform-fee))
    )
        ;; Validate inputs
        (asserts! (is-valid-subject subject) ERR-INVALID-INPUT)
        (asserts! (> duration-hours u0) ERR-INVALID-AMOUNT)
        (asserts! (> start-time block-height) ERR-INVALID-TIME-SLOT)
        (asserts! (get is-active tutor-data) ERR-TUTOR-NOT-AVAILABLE)
        
        ;; Transfer payment to escrow
        (try! (stx-transfer? total-with-fee tx-sender (as-contract tx-sender)))
        
        ;; Create the session
        (map-set sessions session-id {
            session-id: session-id,
            tutor: tutor,
            student: tx-sender,
            subject: subject,
            start-time: start-time,
            duration-hours: duration-hours,
            hourly-rate: (get hourly-rate tutor-data),
            total-amount: total-amount,
            status: STATUS-PENDING,
            created-at: block-height,
            completed-at: none
        })
        
        ;; Set up escrow
        (map-set session-escrow session-id {
            amount: total-with-fee,
            paid: true,
            released: false
        })
        
        ;; Update session counter
        (var-set session-counter session-id)
        
        (ok session-id)
    )
)

;; Function for tutor to confirm a session
(define-public (confirm-session (session-id uint))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
    )
        ;; Validate authorization and status
        (asserts! (is-eq (get tutor session-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get status session-data) STATUS-PENDING) ERR-INVALID-STATUS)
        
        ;; Update session status
        (map-set sessions session-id
            (merge session-data { status: STATUS-CONFIRMED })
        )
        
        (ok true)
    )
)

;; Function to start a session
(define-public (start-session (session-id uint))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
    )
        ;; Only tutor can start the session
        (asserts! (is-eq (get tutor session-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get status session-data) STATUS-CONFIRMED) ERR-INVALID-STATUS)
        
        ;; Update session status
        (map-set sessions session-id
            (merge session-data { status: STATUS-IN-PROGRESS })
        )
        
        (ok true)
    )
)

;; Function to complete a session
(define-public (complete-session (session-id uint))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
    )
        ;; Only tutor can mark session as complete
        (asserts! (is-eq (get tutor session-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get status session-data) STATUS-IN-PROGRESS) ERR-INVALID-STATUS)
        
        ;; Update session status
        (map-set sessions session-id
            (merge session-data { 
                status: STATUS-COMPLETED,
                completed-at: (some block-height)
            })
        )
        
        (ok true)
    )
)

;; Function to release payment after session completion
(define-public (release-payment (session-id uint))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
        (escrow-data (unwrap! (map-get? session-escrow session-id) ERR-SESSION-NOT-FOUND))
        (tutor-data (unwrap! (map-get? tutors (get tutor session-data)) ERR-TUTOR-NOT-FOUND))
        (student-data (unwrap! (map-get? students (get student session-data)) ERR-STUDENT-NOT-FOUND))
        (platform-fee (/ (* (get total-amount session-data) PLATFORM-FEE-BPS) BASIS-POINTS))
        (tutor-payment (get total-amount session-data))
    )
        ;; Validate session is completed and payment not already released
        (asserts! (is-eq (get status session-data) STATUS-COMPLETED) ERR-SESSION-NOT-COMPLETED)
        (asserts! (not (get released escrow-data)) ERR-PAYMENT-ALREADY-PROCESSED)
        
        ;; Transfer payment to tutor
        (try! (as-contract (stx-transfer? tutor-payment tx-sender (get tutor session-data))))
        
        ;; Update platform earnings
        (var-set platform-earnings (+ (var-get platform-earnings) platform-fee))
        
        ;; Update escrow status
        (map-set session-escrow session-id
            (merge escrow-data { released: true })
        )
        
        ;; Update tutor earnings
        (map-set tutors (get tutor session-data)
            (merge tutor-data { 
                total-earnings: (+ (get total-earnings tutor-data) tutor-payment)
            })
        )
        
        ;; Update student spending
        (map-set students (get student session-data)
            (merge student-data { 
                total-spent: (+ (get total-spent student-data) (get total-amount session-data)),
                total-sessions: (+ (get total-sessions student-data) u1)
            })
        )
        
        (ok true)
    )
)

;; Function to rate a completed session
(define-public (rate-session (session-id uint) (rating uint) (comment (string-ascii 200)))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
        (current-ratings (default-to {
            tutor-rating: none,
            student-rating: none,
            tutor-comment: none,
            student-comment: none
        } (map-get? session-ratings session-id)))
        (is-tutor (is-eq tx-sender (get tutor session-data)))
        (is-student (is-eq tx-sender (get student session-data)))
    )
        ;; Validate session is completed
        (asserts! (is-eq (get status session-data) STATUS-COMPLETED) ERR-SESSION-NOT-COMPLETED)
        
        ;; Validate rating range
        (asserts! (and (>= rating MIN-RATING) (<= rating MAX-RATING)) ERR-RATING-OUT-OF-RANGE)
        
        ;; Validate comment (allow empty comments)
        (asserts! (<= (len comment) u200) ERR-INVALID-INPUT)
        
        ;; Validate user is part of the session
        (asserts! (or is-tutor is-student) ERR-UNAUTHORIZED-ACCESS)
        
        (if is-tutor
            ;; Tutor rating student
            (begin
                (map-set session-ratings session-id
                    (merge current-ratings {
                        tutor-rating: (some rating),
                        tutor-comment: (some comment)
                    })
                )
                (ok true)
            )
            ;; Student rating tutor
            (let (
                (tutor-data (unwrap! (map-get? tutors (get tutor session-data)) ERR-TUTOR-NOT-FOUND))
                (current-total-ratings (get total-ratings tutor-data))
                (current-rating (get rating tutor-data))
                (new-total-ratings (+ current-total-ratings u1))
                (new-average-rating (/ (+ (* current-rating current-total-ratings) rating) new-total-ratings))
            )
                ;; Update session ratings
                (map-set session-ratings session-id
                    (merge current-ratings {
                        student-rating: (some rating),
                        student-comment: (some comment)
                    })
                )
                
                ;; Update tutor's average rating
                (map-set tutors (get tutor session-data)
                    (merge tutor-data {
                        rating: new-average-rating,
                        total-ratings: new-total-ratings
                    })
                )
                
                (ok true)
            )
        )
    )
)

;; Function to raise a dispute
(define-public (raise-dispute (session-id uint) (reason (string-ascii 200)))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
        (dispute-id (+ (var-get dispute-counter) u1))
        (is-participant (or 
            (is-eq tx-sender (get tutor session-data))
            (is-eq tx-sender (get student session-data))
        ))
    )
        ;; Validate input
        (asserts! (is-valid-reason reason) ERR-INVALID-INPUT)
        
        ;; Validate user is part of the session
        (asserts! is-participant ERR-UNAUTHORIZED-ACCESS)
        
        ;; Check if dispute already exists for this session
        (asserts! (is-none (map-get? disputes session-id)) ERR-DISPUTE-ALREADY-EXISTS)
        
        ;; Create dispute
        (map-set disputes dispute-id {
            session-id: session-id,
            raised-by: tx-sender,
            reason: reason,
            status: STATUS-PENDING,
            resolved-at: none,
            resolution: none
        })
        
        ;; Update session status
        (map-set sessions session-id
            (merge session-data { status: STATUS-DISPUTED })
        )
        
        ;; Update dispute counter
        (var-set dispute-counter dispute-id)
        
        (ok dispute-id)
    )
)

;; Function to cancel a session (only before it starts)
(define-public (cancel-session (session-id uint))
    (let (
        (session-data (unwrap! (map-get? sessions session-id) ERR-SESSION-NOT-FOUND))
        (escrow-data (unwrap! (map-get? session-escrow session-id) ERR-SESSION-NOT-FOUND))
        (is-participant (or 
            (is-eq tx-sender (get tutor session-data))
            (is-eq tx-sender (get student session-data))
        ))
    )
        ;; Validate authorization
        (asserts! is-participant ERR-UNAUTHORIZED-ACCESS)
        
        ;; Can only cancel pending or confirmed sessions
        (asserts! (or 
            (is-eq (get status session-data) STATUS-PENDING)
            (is-eq (get status session-data) STATUS-CONFIRMED)
        ) ERR-INVALID-STATUS)
        
        ;; Refund the student
        (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get student session-data))))
        
        ;; Update session status
        (map-set sessions session-id
            (merge session-data { status: STATUS-CANCELLED })
        )
        
        ;; Update escrow
        (map-set session-escrow session-id
            (merge escrow-data { released: true })
        )
        
        (ok true)
    )
)

;; Function to update tutor availability
(define-public (update-tutor-availability (is-active bool))
    (let (
        (tutor-data (unwrap! (map-get? tutors tx-sender) ERR-TUTOR-NOT-FOUND))
    )
        (map-set tutors tx-sender
            (merge tutor-data { is-active: is-active })
        )
        (ok true)
    )
)

;; Function to update tutor hourly rate
(define-public (update-hourly-rate (new-rate uint))
    (let (
        (tutor-data (unwrap! (map-get? tutors tx-sender) ERR-TUTOR-NOT-FOUND))
    )
        (asserts! (> new-rate u0) ERR-INVALID-AMOUNT)
        
        (map-set tutors tx-sender
            (merge tutor-data { hourly-rate: new-rate })
        )
        (ok true)
    )
)

;; Admin function to resolve disputes
(define-public (resolve-dispute (dispute-id uint) (resolution (string-ascii 200)))
    (let (
        (dispute-data (unwrap! (map-get? disputes dispute-id) ERR-SESSION-NOT-FOUND))
    )
        ;; Only contract owner can resolve disputes
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        
        ;; Validate dispute ID is within valid range
        (asserts! (and (> dispute-id u0) (<= dispute-id (var-get dispute-counter))) ERR-SESSION-NOT-FOUND)
        
        ;; Validate resolution input
        (asserts! (is-valid-resolution resolution) ERR-INVALID-INPUT)
        
        ;; Validate dispute is still pending
        (asserts! (is-eq (get status dispute-data) STATUS-PENDING) ERR-INVALID-STATUS)
        
        ;; Update dispute
        (map-set disputes dispute-id
            (merge dispute-data {
                status: STATUS-COMPLETED,
                resolved-at: (some block-height),
                resolution: (some resolution)
            })
        )
        
        (ok true)
    )
)

;; Admin function to withdraw platform earnings
(define-public (withdraw-platform-earnings)
    (let (
        (earnings (var-get platform-earnings))
    )
        ;; Only contract owner can withdraw
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> earnings u0) ERR-INSUFFICIENT-BALANCE)
        
        ;; Transfer earnings to owner
        (try! (as-contract (stx-transfer? earnings tx-sender CONTRACT-OWNER)))
        
        ;; Reset platform earnings
        (var-set platform-earnings u0)
        
        (ok earnings)
    )
)

;; Read-only function to get tutor details
(define-read-only (get-tutor (tutor principal))
    (map-get? tutors tutor)
)

;; Read-only function to get student details
(define-read-only (get-student (student principal))
    (map-get? students student)
)

;; Read-only function to get session details
(define-read-only (get-session (session-id uint))
    (map-get? sessions session-id)
)

;; Read-only function to get session ratings
(define-read-only (get-session-ratings (session-id uint))
    (map-get? session-ratings session-id)
)

;; Read-only function to get dispute details
(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes dispute-id)
)

;; Read-only function to get current session counter
(define-read-only (get-session-counter)
    (var-get session-counter)
)

;; Read-only function to get platform earnings
(define-read-only (get-platform-earnings)
    (var-get platform-earnings)
)

;; Read-only function to calculate session cost including fees
(define-read-only (calculate-session-cost (tutor principal) (duration-hours uint))
    (match (map-get? tutors tutor)
        tutor-data
        (let (
            (base-cost (* (get hourly-rate tutor-data) duration-hours))
            (platform-fee (/ (* base-cost PLATFORM-FEE-BPS) BASIS-POINTS))
        )
            (ok {
                base-cost: base-cost,
                platform-fee: platform-fee,
                total-cost: (+ base-cost platform-fee)
            })
        )
        ERR-TUTOR-NOT-FOUND
    )
)