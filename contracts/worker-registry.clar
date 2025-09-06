
;; title: worker-registry
;; version: 1.0.0
;; summary: Decentralized registry for informal worker skill profiles
;; description: Core contract for managing portable, verifiable worker profiles with skill tracking

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_PROFILE_NOT_FOUND (err u404))
(define-constant ERR_PROFILE_EXISTS (err u409))
(define-constant ERR_SKILL_NOT_FOUND (err u410))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_SKILL_EXISTS (err u411))
(define-constant ERR_PORTFOLIO_LIMIT_EXCEEDED (err u412))
(define-constant ERR_SPECIALIZATION_LIMIT_EXCEEDED (err u413))

;; Profile status constants
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_INACTIVE u0)
(define-constant STATUS_SUSPENDED u2)

;; Skill proficiency levels (1-5 scale)
(define-constant PROFICIENCY_BEGINNER u1)
(define-constant PROFICIENCY_NOVICE u2)
(define-constant PROFICIENCY_INTERMEDIATE u3)
(define-constant PROFICIENCY_ADVANCED u4)
(define-constant PROFICIENCY_EXPERT u5)

;; Maximum limits
(define-constant MAX_SKILLS_PER_PROFILE u50)
(define-constant MAX_PORTFOLIO_ITEMS u10)
(define-constant MAX_SPECIALIZATIONS u5)

;; data vars
(define-data-var total-profiles uint u0)
(define-data-var total-skills-registered uint u0)

;; data maps
(define-map worker-profiles
    principal
    {
        name: (string-ascii 100),
        bio: (string-ascii 500),
        portfolio-url: (optional (string-ascii 200)),
        contact-info: (optional (string-ascii 100)),
        location: (optional (string-ascii 100)),
        status: uint,
        created-at: uint,
        updated-at: uint,
        total-skills: uint,
        verification-score: uint,
        profile-views: uint,
        is-public: bool
    }
)

(define-map worker-skills
    { worker: principal, skill-name: (string-ascii 50) }
    {
        category: (string-ascii 30),
        years-experience: uint,
        proficiency-level: uint,
        specializations: (list 5 (string-ascii 30)),
        added-at: uint,
        last-updated: uint,
        verification-count: uint,
        avg-verification-score: uint
    }
)

(define-map skill-categories
    (string-ascii 30)
    {
        description: (string-ascii 200),
        skill-count: uint,
        is-active: bool
    }
)

(define-map worker-portfolio
    { worker: principal, item-index: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 300),
        url: (string-ascii 200),
        skill-tags: (list 5 (string-ascii 30)),
        added-at: uint
    }
)

(define-map worker-statistics
    principal
    {
        profile-completeness: uint, ;; percentage 0-100
        last-activity: uint,
        endorsement-count: uint,
        skill-verification-count: uint,
        reputation-score: uint
    }
)

(define-map skill-registry
    (string-ascii 50)
    {
        worker-count: uint,
        avg-experience: uint,
        avg-proficiency: uint,
        category: (string-ascii 30),
        is-verified-skill: bool
    }
)

;; public functions

;; Create a new worker profile
(define-public (create-worker-profile (name (string-ascii 100))
                                      (bio (string-ascii 500))
                                      (portfolio-url (optional (string-ascii 200)))
                                      (contact-info (optional (string-ascii 100))))
    (let
        (
            (current-time u1000) ;; Using constant for demo
        )
        ;; Check if profile already exists
        (asserts! (is-none (map-get? worker-profiles tx-sender)) ERR_PROFILE_EXISTS)
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_INPUT)
        (asserts! (> (len bio) u0) ERR_INVALID_INPUT)
        
        ;; Create profile
        (map-set worker-profiles tx-sender
            {
                name: name,
                bio: bio,
                portfolio-url: portfolio-url,
                contact-info: contact-info,
                location: none,
                status: STATUS_ACTIVE,
                created-at: current-time,
                updated-at: current-time,
                total-skills: u0,
                verification-score: u0,
                profile-views: u0,
                is-public: true
            }
        )
        
        ;; Initialize statistics
        (map-set worker-statistics tx-sender
            {
                profile-completeness: u30, ;; Base completion for basic profile
                last-activity: current-time,
                endorsement-count: u0,
                skill-verification-count: u0,
                reputation-score: u0
            }
        )
        
        ;; Update global counter
        (var-set total-profiles (+ (var-get total-profiles) u1))
        
        (ok true)
    )
)

;; Add a skill to worker profile
(define-public (add-skill (skill-name (string-ascii 50))
                         (category (string-ascii 30))
                         (years-experience uint)
                         (proficiency-level uint)
                         (specializations (list 5 (string-ascii 30))))
    (let
        (
            (worker-profile (unwrap! (map-get? worker-profiles tx-sender) ERR_PROFILE_NOT_FOUND))
            (skill-key { worker: tx-sender, skill-name: skill-name })
            (current-time u1000)
        )
        ;; Validate inputs
        (asserts! (> (len skill-name) u0) ERR_INVALID_INPUT)
        (asserts! (> (len category) u0) ERR_INVALID_INPUT)
        (asserts! (and (>= proficiency-level PROFICIENCY_BEGINNER)
                      (<= proficiency-level PROFICIENCY_EXPERT)) ERR_INVALID_INPUT)
        (asserts! (<= (len specializations) MAX_SPECIALIZATIONS) ERR_SPECIALIZATION_LIMIT_EXCEEDED)
        (asserts! (< (get total-skills worker-profile) MAX_SKILLS_PER_PROFILE) ERR_INVALID_INPUT)
        
        ;; Check if skill already exists
        (asserts! (is-none (map-get? worker-skills skill-key)) ERR_SKILL_EXISTS)
        
        ;; Add skill
        (map-set worker-skills skill-key
            {
                category: category,
                years-experience: years-experience,
                proficiency-level: proficiency-level,
                specializations: specializations,
                added-at: current-time,
                last-updated: current-time,
                verification-count: u0,
                avg-verification-score: u0
            }
        )
        
        ;; Update worker profile
        (map-set worker-profiles tx-sender
            (merge worker-profile {
                total-skills: (+ (get total-skills worker-profile) u1),
                updated-at: current-time
            })
        )
        
        ;; Update skill registry
        (let ((skill-data (default-to 
                          { worker-count: u0, avg-experience: u0, avg-proficiency: u0, category: category, is-verified-skill: false }
                          (map-get? skill-registry skill-name))))
            (map-set skill-registry skill-name
                (merge skill-data {
                    worker-count: (+ (get worker-count skill-data) u1)
                })
            )
        )
        
        ;; Update statistics
        (let ((stats (unwrap! (map-get? worker-statistics tx-sender) ERR_PROFILE_NOT_FOUND)))
            (map-set worker-statistics tx-sender
                (merge stats {
                    last-activity: current-time,
                    profile-completeness: (+ (get profile-completeness stats) u10) ;; Increase completion score
                })
            )
        )
        
        ;; Update global counter
        (var-set total-skills-registered (+ (var-get total-skills-registered) u1))
        
        (ok true)
    )
)

;; Update skill information
(define-public (update-skill (skill-name (string-ascii 50))
                           (years-experience uint)
                           (proficiency-level uint)
                           (specializations (list 5 (string-ascii 30))))
    (let
        (
            (skill-key { worker: tx-sender, skill-name: skill-name })
            (existing-skill (unwrap! (map-get? worker-skills skill-key) ERR_SKILL_NOT_FOUND))
            (current-time u1000)
        )
        ;; Validate inputs
        (asserts! (and (>= proficiency-level PROFICIENCY_BEGINNER)
                      (<= proficiency-level PROFICIENCY_EXPERT)) ERR_INVALID_INPUT)
        (asserts! (<= (len specializations) MAX_SPECIALIZATIONS) ERR_SPECIALIZATION_LIMIT_EXCEEDED)
        
        ;; Update skill
        (map-set worker-skills skill-key
            (merge existing-skill {
                years-experience: years-experience,
                proficiency-level: proficiency-level,
                specializations: specializations,
                last-updated: current-time
            })
        )
        
        ;; Update worker profile timestamp
        (let ((worker-profile (unwrap! (map-get? worker-profiles tx-sender) ERR_PROFILE_NOT_FOUND)))
            (map-set worker-profiles tx-sender
                (merge worker-profile {
                    updated-at: current-time
                })
            )
        )
        
        ;; Update statistics
        (let ((stats (unwrap! (map-get? worker-statistics tx-sender) ERR_PROFILE_NOT_FOUND)))
            (map-set worker-statistics tx-sender
                (merge stats {
                    last-activity: current-time
                })
            )
        )
        
        (ok true)
    )
)

;; Add portfolio item
(define-public (add-portfolio-item (title (string-ascii 100))
                                  (description (string-ascii 300))
                                  (url (string-ascii 200))
                                  (skill-tags (list 5 (string-ascii 30))))
    (let
        (
            (worker-profile (unwrap! (map-get? worker-profiles tx-sender) ERR_PROFILE_NOT_FOUND))
            (current-time u1000)
            (next-index (get total-skills worker-profile)) ;; Using total skills as portfolio index approximation
        )
        ;; Validate inputs
        (asserts! (> (len title) u0) ERR_INVALID_INPUT)
        (asserts! (> (len description) u0) ERR_INVALID_INPUT)
        (asserts! (> (len url) u0) ERR_INVALID_INPUT)
        
        ;; Check portfolio limit (simplified)
        (asserts! (< next-index MAX_PORTFOLIO_ITEMS) ERR_PORTFOLIO_LIMIT_EXCEEDED)
        
        ;; Add portfolio item
        (map-set worker-portfolio { worker: tx-sender, item-index: next-index }
            {
                title: title,
                description: description,
                url: url,
                skill-tags: skill-tags,
                added-at: current-time
            }
        )
        
        ;; Update statistics
        (let ((stats (unwrap! (map-get? worker-statistics tx-sender) ERR_PROFILE_NOT_FOUND)))
            (map-set worker-statistics tx-sender
                (merge stats {
                    last-activity: current-time,
                    profile-completeness: (+ (get profile-completeness stats) u5)
                })
            )
        )
        
        (ok true)
    )
)

;; Update profile visibility
(define-public (set-profile-visibility (is-public bool))
    (let
        (
            (worker-profile (unwrap! (map-get? worker-profiles tx-sender) ERR_PROFILE_NOT_FOUND))
            (current-time u1000)
        )
        ;; Update profile
        (map-set worker-profiles tx-sender
            (merge worker-profile {
                is-public: is-public,
                updated-at: current-time
            })
        )
        
        (ok true)
    )
)

;; Register a new skill category (admin function)
(define-public (register-skill-category (category-name (string-ascii 30))
                                       (description (string-ascii 200)))
    (begin
        ;; Only contract owner can register categories
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        
        ;; Register category
        (map-set skill-categories category-name
            {
                description: description,
                skill-count: u0,
                is-active: true
            }
        )
        
        (ok true)
    )
)

;; read only functions

(define-read-only (get-worker-profile (worker principal))
    (map-get? worker-profiles worker)
)

(define-read-only (get-worker-skill (worker principal) (skill-name (string-ascii 50)))
    (map-get? worker-skills { worker: worker, skill-name: skill-name })
)

(define-read-only (get-worker-statistics (worker principal))
    (map-get? worker-statistics worker)
)

(define-read-only (get-portfolio-item (worker principal) (item-index uint))
    (map-get? worker-portfolio { worker: worker, item-index: item-index })
)

(define-read-only (get-skill-category (category-name (string-ascii 30)))
    (map-get? skill-categories category-name)
)

(define-read-only (get-skill-registry (skill-name (string-ascii 50)))
    (map-get? skill-registry skill-name)
)

(define-read-only (get-total-profiles)
    (var-get total-profiles)
)

(define-read-only (get-total-skills)
    (var-get total-skills-registered)
)

(define-read-only (has-profile (worker principal))
    (is-some (map-get? worker-profiles worker))
)

(define-read-only (has-skill (worker principal) (skill-name (string-ascii 50)))
    (is-some (map-get? worker-skills { worker: worker, skill-name: skill-name }))
)

;; private functions

(define-private (calculate-profile-completeness (worker principal))
    (let
        (
            (profile (map-get? worker-profiles worker))
            (stats (map-get? worker-statistics worker))
        )
        (match profile
            profile-data
                (let
                    (
                        (base-score u30)
                        (skill-bonus (* (get total-skills profile-data) u5))
                        (contact-bonus (if (is-some (get contact-info profile-data)) u10 u0))
                        (portfolio-bonus (if (is-some (get portfolio-url profile-data)) u10 u0))
                    )
                    (let ((total-score (+ base-score skill-bonus contact-bonus portfolio-bonus)))
                        (if (> total-score u100) u100 total-score))
                )
            u0
        )
    )
)

(define-private (is-valid-proficiency-level (level uint))
    (and (>= level PROFICIENCY_BEGINNER) (<= level PROFICIENCY_EXPERT))
)

