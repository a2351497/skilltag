# Skilltag - Informal Worker Registry

A decentralized skill verification and portable worker profile system built on the Stacks blockchain using Clarity smart contracts. Skilltag empowers informal workers to create verified, portable skill profiles that can be used across multiple platforms and employers.

## 🚀 Overview

Skilltag addresses the challenge faced by informal workers who lack traditional credentials but possess valuable skills. The system enables workers to build verifiable skill profiles that are:

- **Portable**: Owned and controlled by the worker, not tied to any single platform
- **Verifiable**: Skills backed by blockchain-based verification from trusted sources
- **Comprehensive**: Multi-dimensional skill tracking with proficiency levels and specializations
- **Persistent**: Permanent record that builds over time, creating a worker's digital reputation

## 🔧 Core Features

- **Skill Profile Creation**: Workers can create comprehensive skill profiles with multiple competencies
- **Verification System**: Trusted verifiers can validate and endorse worker skills
- **Skill Categories**: Organized skill taxonomy covering trades, services, and professional skills
- **Experience Tracking**: Record years of experience and proficiency levels for each skill
- **Portfolio Integration**: Link to work samples, certifications, and external profiles
- **Reputation Building**: Aggregate verification scores and endorsement history
- **Privacy Controls**: Workers control what information is public vs. private

## 📋 Smart Contracts

### `worker-registry.clar`
Core contract managing worker profiles, skill registration, and identity verification.

### `skill-verifier.clar`
Handles skill verification processes, verifier management, and endorsement systems.

## 🛠 Technology Stack

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest + TypeScript

## 📦 Project Structure

```
skilltag/
├── contracts/           # Clarity smart contracts
├── tests/              # Contract tests
├── settings/           # Network configuration
├── Clarinet.toml       # Project configuration
└── package.json        # Dependencies and scripts
```

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for running tests

### Installation
```bash
git clone <repository-url>
cd skilltag
npm install
```

### Testing
```bash
clarinet check          # Validate contract syntax
npm test                # Run full test suite
```

### Local Development
```bash
clarinet console        # Interactive Clarity console
clarinet integrate      # Integration testing
```

## 📈 Contract Usage Examples

### Creating a Worker Profile
```clarity
;; Register as a worker with basic profile information
(contract-call? .worker-registry create-worker-profile
  "John Doe"
  "Experienced carpenter and electrician"
  "https://portfolio.example.com"
  "+1234567890")
```

### Adding Skills
```clarity
;; Add carpentry skill with 5 years experience
(contract-call? .worker-registry add-skill
  "Carpentry"
  u5    ;; years of experience
  u4    ;; proficiency level (1-5)
  (list "Framing" "Finish Work" "Cabinetry"))  ;; specializations
```

### Skill Verification
```clarity
;; Verify a worker's skill as a trusted verifier
(contract-call? .skill-verifier verify-skill
  'SP1ABCDE...   ;; worker principal
  "Carpentry"
  u4             ;; verified proficiency level
  "Excellent craftsmanship and attention to detail")
```

## 🎯 Use Cases

### For Informal Workers
- Create a comprehensive, verifiable skill profile
- Build reputation across multiple platforms
- Demonstrate competencies to potential employers
- Maintain ownership of their professional identity

### For Employers/Platforms
- Access to pre-verified worker skills
- Reduced hiring risk through skill validation
- Tap into informal labor markets with confidence
- Lower onboarding costs for skilled workers

### For Verifiers (Training Organizations, Past Employers)
- Provide value-added services to workers
- Build reputation as trusted skill validators
- Create new revenue streams through verification services
- Support workforce development initiatives

## 🔄 Future Enhancements

While this implementation provides a solid foundation, potential future enhancements could include:
- Integration with existing credential systems
- Skill-based matching algorithms
- Payment and contract management
- Multi-language support for global accessibility
- Mobile-first interface for accessibility

## 🤝 Contributing

This project demonstrates Clarity smart contract development patterns for workforce and credential management systems.

## 📄 License

MIT License - see LICENSE file for details.

## 🔗 Resources

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)
