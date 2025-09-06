
;; title: skill-verifier
;; version: 1.0.0
;; summary: Skill verification and endorsement system for worker profiles
;; description: Manages trusted verifiers and skill validation processes

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_VERIFIER_NOT_FOUND (err u404))
(define-constant ERR_WORKER_NOT_FOUND (err u405))
(define-constant ERR_SKILL_NOT_FOUND (err u406))
(define-constant ERR_VERIFICATION_EXISTS (err u409))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_VERIFIER_NOT_ACTIVE (err u410))
(define-constant ERR_SELF_VERIFICATION (err u411))
(define-constant ERR_VERIFICATION_NOT_FOUND (err u412))
(define-constant ERR_CHALLENGE_NOT_FOUND (err u413))
(define-constant ERR_CHALLENGE_EXPIRED (err u414))

;; Verifier status constants
(define-constant VERIFIER_STATUS_ACTIVE u1)
(define-constant VERIFIER_STATUS_INACTIVE u0)
(define-constant VERIFIER_STATUS_SUSPENDED u2)

;; Verification status constants
(define-constant VERIFICATION_STATUS_PENDING u0)
(define-constant VERIFICATION_STATUS_VERIFIED u1)
(define-constant VERIFICATION_STATUS_REJECTED u2)
(define-constant VERIFICATION_STATUS_DISPUTED u3)

;; Verifier type constants
(define-constant VERIFIER_TYPE_EMPLOYER u1)
(define-constant VERIFIER_TYPE_INSTITUTION u2)
(define-constant VERIFIER_TYPE_PEER u3)
(define-constant VERIFIER_TYPE_CERTIFICATION_BODY u4)

;; Challenge type constants
(define-constant CHALLENGE_TYPE_SKILL_TEST u1)
(define-constant CHALLENGE_TYPE_PORTFOLIO_REVIEW u2)
(define-constant CHALLENGE_TYPE_PRACTICAL_DEMO u3)

;; Rating constants
(define-constant MIN_RATING u1)
(define-constant MAX_RATING u5)

;; data vars
(define-data-var total-verifiers uint u0)
(define-data-var total-verifications uint u0)
(define-data-var verification-nonce uint u0)
(define-data-var challenge-nonce uint u0)

;; data maps
(define-map trusted-verifiers
    principal
    {
        name: (string-ascii 100),
        organization: (string-ascii 100),
        verifier-type: uint,
        specialization: (string-ascii 50),
        status: uint,
        reputation-score: uint,
        total-verifications: uint,
        successful-verifications: uint,
        registered-at: uint,
        contact-info: (optional (string-ascii 100))
    }
)

(define-map skill-verifications
    uint ;; verification-id
    {
        worker: principal,
        verifier: principal,
        skill-name: (string-ascii 50),
        proficiency-rating: uint,
        verification-type: uint,
        status: uint,
        verification-notes: (string-ascii 300),
        evidence-url: (optional (string-ascii 200)),
        verified-at: uint,
        expires-at: (optional uint)
    }
)

(define-map worker-verifications
    { worker: principal, skill-name: (string-ascii 50) }
    {
        total-verifications: uint,
        verified-count: uint,
        avg-rating: uint,
        latest-verification: (optional uint),
        verification-ids: (list 10 uint)
    }
)

(define-map skill-challenges
    uint ;; challenge-id
    {
        challenger: principal,
        worker: principal,
        skill-name: (string-ascii 50),
        challenge-type: uint,
        challenge-description: (string-ascii 300),
        requirements: (string-ascii 300),
        deadline: uint,
        status: uint,
        created-at: uint,
        reward-amount: uint
    }
)

(define-map endorsements
    { endorser: principal, worker: principal, skill-name: (string-ascii 50) }
    {
        endorsement-text: (string-ascii 200),
        rating: uint,
        relationship: (string-ascii 50),
        created-at: uint,
        is-public: bool
    }
)

(define-map verifier-specializations
    { verifier: principal, specialization: (string-ascii 50) }
    {
        certification-level: uint,
        years-experience: uint,
        verified-workers: uint,
        success-rate: uint
    }
)

(define-map verification-disputes
    uint ;; verification-id
    {
        disputed-by: principal,
        dispute-reason: (string-ascii 300),
        dispute-details: (string-ascii 500),
        created-at: uint,
        status: uint,
        resolved-at: (optional uint)
    }
)

;; public functions

;; Register as a trusted verifier
(define-public (register-verifier (name (string-ascii 100))
                                 (organization (string-ascii 100))
                                 (verifier-type uint)
                                 (specialization (string-ascii 50))
                                 (contact-info (optional (string-ascii 100))))
    (let
        (
            (current-time u1000)
        )
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (asserts! (> (len organization) u0) ERR_INVALID_INPUT)
        (asserts! (and (>= verifier-type VERIFIER_TYPE_EMPLOYER)
                      (<= verifier-type VERIFIER_TYPE_CERTIFICATION_BODY)) ERR_INVALID_INPUT)
        
        ;; Register verifier
        (map-set trusted-verifiers tx-sender
            {
                name: name,
                organization: organization,
                verifier-type: verifier-type,
                specialization: specialization,
                status: VERIFIER_STATUS_ACTIVE,
                reputation-score: u100, ;; Starting reputation
                total-verifications: u0,
                successful-verifications: u0,
                registered-at: current-time,
                contact-info: contact-info
            }
        )
        
        ;; Add specialization record
        (map-set verifier-specializations { verifier: tx-sender, specialization: specialization }
            {
                certification-level: u1,
                years-experience: u0,
                verified-workers: u0,
                success-rate: u100
            }
        )
        
        ;; Update counter
        (var-set total-verifiers (+ (var-get total-verifiers) u1))
        
        (ok true)
    )
)

;; Verify a worker's skill
(define-public (verify-skill (worker principal)
                            (skill-name (string-ascii 50))
                            (proficiency-rating uint)
                            (verification-notes (string-ascii 300))
                            (evidence-url (optional (string-ascii 200))))
    (let
        (
            (verifier-data (unwrap! (map-get? trusted-verifiers tx-sender) ERR_VERIFIER_NOT_FOUND))
            (verification-id (+ (var-get verification-nonce) u1))
            (current-time u1000)
            (verification-key { worker: worker, skill-name: skill-name })
        )
        ;; Validate verifier status
        (asserts! (is-eq (get status verifier-data) VERIFIER_STATUS_ACTIVE) ERR_VERIFIER_NOT_ACTIVE)
        ;; Prevent self-verification
        (asserts! (not (is-eq tx-sender worker)) ERR_SELF_VERIFICATION)
        ;; Validate rating
        (asserts! (and (>= proficiency-rating MIN_RATING)
                      (<= proficiency-rating MAX_RATING)) ERR_INVALID_INPUT)
        
        ;; Create verification record
        (map-set skill-verifications verification-id
            {
                worker: worker,
                verifier: tx-sender,
                skill-name: skill-name,
                proficiency-rating: proficiency-rating,
                verification-type: (get verifier-type verifier-data),
                status: VERIFICATION_STATUS_VERIFIED,
                verification-notes: verification-notes,
                evidence-url: evidence-url,
                verified-at: current-time,
                expires-at: none
            }
        )
        
        ;; Update worker verification summary
        (let ((worker-verif-data (default-to 
                                 { total-verifications: u0, verified-count: u0, avg-rating: u0, latest-verification: none, verification-ids: (list) }
                                 (map-get? worker-verifications verification-key))))
            (map-set worker-verifications verification-key
                (merge worker-verif-data {
                    total-verifications: (+ (get total-verifications worker-verif-data) u1),
                    verified-count: (+ (get verified-count worker-verif-data) u1),
                    latest-verification: (some verification-id)
                    ;; Note: avg-rating calculation simplified for demo
                })
            )
        )
        
        ;; Update verifier stats
        (map-set trusted-verifiers tx-sender
            (merge verifier-data {
                total-verifications: (+ (get total-verifications verifier-data) u1),
                successful-verifications: (+ (get successful-verifications verifier-data) u1)
            })
        )
        
        ;; Update counters
        (var-set verification-nonce verification-id)
        (var-set total-verifications (+ (var-get total-verifications) u1))
        
        (ok verification-id)
    )
)

;; Create a skill challenge
(define-public (create-skill-challenge (worker principal)
                                      (skill-name (string-ascii 50))
                                      (challenge-type uint)
                                      (challenge-description (string-ascii 300))
                                      (requirements (string-ascii 300))
                                      (deadline-days uint)
                                      (reward-amount uint))
    (let
        (
            (challenge-id (+ (var-get challenge-nonce) u1))
            (current-time u1000)
            (deadline (+ current-time (* deadline-days u144))) ;; Assuming 144 blocks per day
        )
        ;; Validate inputs
        (asserts! (> (len challenge-description) u0) ERR_INVALID_INPUT)
        (asserts! (> deadline-days u0) ERR_INVALID_INPUT)
        (asserts! (and (>= challenge-type CHALLENGE_TYPE_SKILL_TEST)
                      (<= challenge-type CHALLENGE_TYPE_PRACTICAL_DEMO)) ERR_INVALID_INPUT)
        
        ;; Create challenge
        (map-set skill-challenges challenge-id
            {
                challenger: tx-sender,
                worker: worker,
                skill-name: skill-name,
                challenge-type: challenge-type,
                challenge-description: challenge-description,
                requirements: requirements,
                deadline: deadline,
                status: VERIFICATION_STATUS_PENDING,
                created-at: current-time,
                reward-amount: reward-amount
            }
        )
        
        ;; Update counter
        (var-set challenge-nonce challenge-id)
        
        (ok challenge-id)
    )
)

;; Submit endorsement for a worker's skill
(define-public (endorse-skill (worker principal)
                             (skill-name (string-ascii 50))
                             (endorsement-text (string-ascii 200))
                             (rating uint)
                             (relationship (string-ascii 50))
                             (is-public bool))
    (let
        (
            (endorsement-key { endorser: tx-sender, worker: worker, skill-name: skill-name })
            (current-time u1000)
        )
        ;; Validate inputs
        (asserts! (> (len endorsement-text) u0) ERR_INVALID_INPUT)
        (asserts! (and (>= rating MIN_RATING) (<= rating MAX_RATING)) ERR_INVALID_INPUT)
        (asserts! (> (len relationship) u0) ERR_INVALID_INPUT)
        ;; Prevent self-endorsement
        (asserts! (not (is-eq tx-sender worker)) ERR_SELF_VERIFICATION)
        
        ;; Create endorsement
        (map-set endorsements endorsement-key
            {
                endorsement-text: endorsement-text,
                rating: rating,
                relationship: relationship,
                created-at: current-time,
                is-public: is-public
            }
        )
        
        (ok true)
    )
)

;; Dispute a verification
(define-public (dispute-verification (verification-id uint)
                                   (dispute-reason (string-ascii 300))
                                   (dispute-details (string-ascii 500)))
    (let
        (
            (verification-data (unwrap! (map-get? skill-verifications verification-id) ERR_VERIFICATION_NOT_FOUND))
            (current-time u1000)
        )
        ;; Only the verified worker can dispute
        (asserts! (is-eq tx-sender (get worker verification-data)) ERR_NOT_AUTHORIZED)
        ;; Validate inputs
        (asserts! (> (len dispute-reason) u0) ERR_INVALID_INPUT)
        
        ;; Create dispute record
        (map-set verification-disputes verification-id
            {
                disputed-by: tx-sender,
                dispute-reason: dispute-reason,
                dispute-details: dispute-details,
                created-at: current-time,
                status: VERIFICATION_STATUS_DISPUTED,
                resolved-at: none
            }
        )
        
        ;; Update verification status
        (map-set skill-verifications verification-id
            (merge verification-data {
                status: VERIFICATION_STATUS_DISPUTED
            })
        )
        
        (ok true)
    )
)

;; Update verifier status (admin function)
(define-public (update-verifier-status (verifier principal) (new-status uint))
    (let
        (
            (verifier-data (unwrap! (map-get? trusted-verifiers verifier) ERR_VERIFIER_NOT_FOUND))
        )
        ;; Only contract owner can update status
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        ;; Validate status
        (asserts! (and (>= new-status VERIFIER_STATUS_INACTIVE)
                      (<= new-status VERIFIER_STATUS_SUSPENDED)) ERR_INVALID_INPUT)
        
        ;; Update status
        (map-set trusted-verifiers verifier
            (merge verifier-data {
                status: new-status
            })
        )
        
        (ok true)
    )
)

;; read only functions

(define-read-only (get-verifier (verifier principal))
    (map-get? trusted-verifiers verifier)
)

(define-read-only (get-skill-verification (verification-id uint))
    (map-get? skill-verifications verification-id)
)

(define-read-only (get-worker-verifications (worker principal) (skill-name (string-ascii 50)))
    (map-get? worker-verifications { worker: worker, skill-name: skill-name })
)

(define-read-only (get-skill-challenge (challenge-id uint))
    (map-get? skill-challenges challenge-id)
)

(define-read-only (get-endorsement (endorser principal) (worker principal) (skill-name (string-ascii 50)))
    (map-get? endorsements { endorser: endorser, worker: worker, skill-name: skill-name })
)

(define-read-only (get-verification-dispute (verification-id uint))
    (map-get? verification-disputes verification-id)
)

(define-read-only (get-verifier-specialization (verifier principal) (specialization (string-ascii 50)))
    (map-get? verifier-specializations { verifier: verifier, specialization: specialization })
)

(define-read-only (get-total-verifiers)
    (var-get total-verifiers)
)

(define-read-only (get-total-verifications)
    (var-get total-verifications)
)

(define-read-only (is-trusted-verifier (verifier principal))
    (match (map-get? trusted-verifiers verifier)
        verifier-data (is-eq (get status verifier-data) VERIFIER_STATUS_ACTIVE)
        false
    )
)

(define-read-only (is-skill-verified (worker principal) (skill-name (string-ascii 50)))
    (match (map-get? worker-verifications { worker: worker, skill-name: skill-name })
        verification-data (> (get verified-count verification-data) u0)
        false
    )
)

;; private functions

(define-private (calculate-verification-score (worker principal) (skill-name (string-ascii 50)))
    (let
        (
            (verification-data (map-get? worker-verifications { worker: worker, skill-name: skill-name }))
        )
        (match verification-data
            data
                (let
                    (
                        (base-score (* (get verified-count data) u10))
                        (rating-bonus (* (get avg-rating data) u5))
                    )
                    (+ base-score rating-bonus)
                )
            u0
        )
    )
)

(define-private (is-verification-expired (verification-id uint))
    (match (map-get? skill-verifications verification-id)
        verification-data
            (match (get expires-at verification-data)
                expiry-date (> u1000 expiry-date) ;; Using constant current time
                false
            )
        true
    )
)

