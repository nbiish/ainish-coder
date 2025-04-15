---
description: 
globs: 
alwaysApply: false
---
## 1. Agile "PRD" / Requirements Management: The Evolving Conversation

Agile methodologies (like Scrum or Kanban) embrace change and iterative development. There isn't typically a single, massive, upfront PRD in the Waterfall sense. Instead, requirements are captured and refined dynamically using various artifacts.

* **Core Philosophy:** Requirements emerge and evolve through collaboration and feedback. Focus on delivering working software incrementally and responding to change. Clarity is achieved *just-in-time*.
* **Timing:** Requirements are defined and refined *continuously* throughout the project lifecycle, often just before and during development iterations (Sprints in Scrum).
* **Purpose:**
    * To guide the development team for the *next* increment of work.
    * To capture user needs and business value concisely.
    * To facilitate ongoing conversation and clarification between the product owner, stakeholders, and the development team.
    * To enable prioritization and adaptation based on feedback and changing priorities.
* **Key Characteristics:**
    * **Iterative & Incremental:** Details are added progressively.
    * **Dynamic & Flexible:** Requirements (especially their priority and specific implementation details) can change based on feedback and learning.
    * **User-Centric:** Often expressed from the user's perspective (User Stories).
    * **Collaborative:** Requirements are understood and refined through discussion.
    * **Lean:** Avoids excessive upfront documentation; details are elaborated "just-in-time."
* **Common Agile Artifacts (Replacing/Supplementing a single PRD):**
    * **Product Vision/Strategy:** A high-level document outlining the overarching goals, target market, and value proposition. Sets the direction.
    * **Product Roadmap:** A high-level, strategic plan showing major features or themes planned over time (quarters, releases). Less detailed than a Waterfall plan.
    * **Product Backlog:** *The primary artifact.* A prioritized, living list of *everything* that might be needed in the product – features, enhancements, bug fixes, technical debt remediation, etc. Items are often represented as:
        * **Epics:** Large bodies of work or features that can be broken down further.
        * **User Stories:** Short descriptions of functionality from an end-user perspective, typically following the format: "As a [type of user], I want [to perform some action] so that [I can achieve some goal/benefit]."
        * **Tasks:** Smaller technical steps needed to complete a User Story.
    * **Sprint Backlog:** The subset of Product Backlog items selected by the team for development during a specific Sprint.
    * **User Stories + Acceptance Criteria (AC):** User Stories become the core requirement units. They are elaborated with specific, testable Acceptance Criteria just before or during a sprint. AC define the conditions that must be met for the story to be considered "Done."
    * **Definition of Done (DoD):** A team agreement on the quality standards and checks that apply to *all* completed work (e.g., code reviewed, unit tests passed, documented, deployed to staging).
    * **Wireframes/Mockups/Prototypes:** Used heavily, but often developed iteratively alongside user stories, rather than being finalized upfront based on a massive PRD.

* **Pros:**
    * Highly adaptable to change and evolving requirements.
    * Faster time-to-market for initial versions (MVP).
    * Focuses on delivering highest-priority value first.
    * Encourages collaboration and incorporates user feedback early and often.
    * Reduces risk of building the wrong product.
    * Less upfront documentation overhead.
* **Cons:**
    * Less predictability regarding final scope, timeline, and cost, especially early on.
    * Requires strong product ownership, team discipline, and continuous communication to avoid chaos or scope creep.
    * Can be harder for external stakeholders (less involved day-to-day) to grasp the full picture at any given moment.
    * Potential for documentation to become fragmented if not managed well (e.g., relying too much on tacit knowledge).

---

## 2. Waterfall PRD: The Comprehensive Blueprint

In the traditional Waterfall model, development phases flow sequentially (Requirements -> Design -> Implementation -> Testing -> Deployment). The PRD is a critical *upfront* artifact.

* **Core Philosophy:** Define *everything* in detail before development starts. The PRD aims to be a complete, stable, and authoritative specification.
* **Timing:** Created and finalized during the initial Requirements phase, *before* any significant design or coding begins. It's often "signed off" by stakeholders.
* **Purpose:**
    * To serve as a single source of truth for the entire project scope.
    * To act as a contract between stakeholders (business, product) and the development team.
    * To minimize ambiguity and prevent scope creep *after* development starts.
    * To guide design, development, and testing phases explicitly.
* **Key Characteristics:**
    * **Comprehensive & Detailed:** Aims to cover every functional and non-functional requirement, edge case, and constraint imaginable *at that point in time*.
    * **Static:** Once finalized, changes are discouraged and typically require a formal (and often cumbersome) change request process.
    * **Formal:** Usually a lengthy, structured document.
    * **Predictive:** Assumes requirements can be fully known and defined upfront.
* **Typical Structure & Contents:**
    * **Introduction:** Project overview, goals, vision, scope (and out-of-scope items).
    * **Assumptions & Dependencies:** Key assumptions made and external factors.
    * **User Personas / Target Audience:** Detailed description of the users.
    * **Functional Requirements:**
        * Often numbered hierarchically (e.g., 1.0 User Login, 1.1 Successful Login, 1.1.1 Input Username, 1.1.2 Input Password...).
        * Describes specific features, user interactions, data handling, workflows, business rules, and system behaviors in exhaustive detail.
        * May include use cases or user scenarios.
    * **Non-Functional Requirements:**
        * Performance (e.g., response times under load).
        * Scalability (e.g., concurrent user limits).
        * Security (e.g., data encryption, authentication methods).
        * Reliability/Availability (e.g., uptime requirements).
        * Usability (though often less emphasized or deferred to design specs).
        * Maintainability.
    * **UI/UX Considerations:** Sometimes includes high-level wireframes or mockups, but often these are part of a separate Design Specification document that follows the PRD.
    * **Release Criteria:** Conditions that must be met for the product to be considered ready for release.
    * **Glossary:** Definitions of terms.
    * **Appendices:** Supporting diagrams, data models, etc.

* **Pros:**
    * Provides clarity and a shared understanding (in theory) before significant investment in development.
    * Reduces ambiguity if done well.
    * Easier to estimate time and cost (if requirements truly don't change).
    * Clear accountability based on the "signed-off" document.
* **Cons:**
    * Very inflexible; difficult and costly to adapt to changing market needs or user feedback discovered later.
    * Requires significant upfront time investment, delaying the start of coding.
    * Risk of building the wrong product if initial assumptions are incorrect ("Analysis Paralysis" or incorrect requirements).
    * Can stifle innovation and iterative improvement.
    * Often becomes outdated quickly but remains the "official" document.

---

## 3. Key Differences Summarized

| Feature             | Agile Requirements Management              | Waterfall PRD                     |
| :------------------ | :----------------------------------------- | :-------------------------------- |
| **Timing** | Continuous, Just-in-time elaboration       | Upfront, before development        |
| **Scope** | Evolves; details emerge iteratively        | Aims to be fully comprehensive     |
| **Detail Level** | High-level initially, detailed "just-in-time" | Exhaustive, highly detailed        |
| **Flexibility** | High; change is expected and embraced      | Low; changes are difficult/costly  |
| **Primary Artifact** | Product Backlog (Epics, User Stories), AC | Single, large PRD document         |
| **Purpose** | Guide iteration, facilitate conversation   | Define contract, minimize change   |
| **Format** | User Stories, Backlogs, collaborative tools | Formal, structured text document   |
| **Collaboration** | High, continuous throughout               | Lower during definition phase      |

---

As a software engineering assistant, understanding these differences is crucial. When working on a project:

* If you receive a massive, detailed PRD upfront, you're likely in a more Waterfall-oriented environment. Your task is to implement the spec precisely. Clarifications might involve formal processes.
* If you're working with a Product Backlog, User Stories, and participating in Sprint Planning, you're in an Agile setup. Expect requirements to be refined collaboratively, and be prepared to provide input and adapt as you build and learn. Your understanding of technologies like Rust, Go, or TypeScript will inform feasibility discussions during backlog refinement.

Both approaches have their place, but Agile is generally favored for complex software development in dynamic environments where learning and adaptation are key.

---

There are several other types of documents related to product requirements, each serving a slightly different purpose or arising from a different methodology or focus area. They often exist alongside or inform the traditional PRD or Agile artifacts.

Here are a few notable ones, presented in the same style as before:

---

## 4. Market Requirements Document (MRD)

* **Core Philosophy:** Define the *market opportunity* and high-level *customer needs* for a product or service before diving into specific product features. It answers the "Why" from a market perspective.
* **Timing:** Typically created very early in the product planning phase, *before* the Product Requirements Document (PRD) or detailed backlog development. It often serves as input for the PRD.
* **Purpose:**
    * To analyze and document the target market, market size, and trends.
    * To identify target customer segments (personas) and their key problems or unmet needs.
    * To analyze the competitive landscape.
    * To define the high-level market opportunity and justify why the product should be built from a business perspective.
    * To guide overall product strategy and positioning.
* **Key Characteristics:**
    * **Market-Focused:** Concentrates on market dynamics, customer needs, and business opportunities rather than specific product functionalities.
    * **Strategic:** Provides high-level direction and justification.
    * **Research-Based:** Relies heavily on market research, competitor analysis, and customer interviews.
    * **Input to PRD:** Defines the context and justification *for* the product described in the PRD.
* **Typical Structure & Contents:**
    * **Executive Summary:** Brief overview of the market opportunity and proposed solution.
    * **Goals:** Business objectives for entering this market/building this product.
    * **Target Market:** Detailed description of the market segment(s).
    * **Personas:** Profiles of typical target customers/users.
    * **Market Needs/Problems:** Identification of key pain points the product will address.
    * **Competitive Analysis:** Overview of existing competitors and alternatives.
    * **High-Level Vision/Capabilities:** Broad description of the proposed solution and its value proposition.
    * **Metrics/Success Criteria:** How market success will be measured (e.g., market share, revenue targets).
    * **(Optional) Pricing & Packaging Strategy:** Initial thoughts on monetization.
* **Pros:**
    * Ensures product development is grounded in market reality and business needs.
    * Provides strong justification for product investment to stakeholders.
    * Helps align product strategy with market opportunities.
    * Guides prioritization based on market impact.
* **Cons:**
    * Requires significant upfront research and analysis effort.
    * Market conditions can change rapidly, potentially making it outdated.
    * Does not define *how* the product will work, only *why* it should exist.
    * Can sometimes be perceived as bureaucratic overhead, especially by highly Agile teams.

---

## 5. Lean PRD / Minimum Viable Product (MVP) Specification

* **Core Philosophy:** Define only the *essential core features* necessary to launch a usable product (the MVP) that delivers value to early adopters and allows the team to test key hypotheses and gather feedback. Focus on maximizing learning with minimal effort.
* **Timing:** Created before the development of an MVP or initial product version. Can be an iterative document itself as the MVP evolves.
* **Purpose:**
    * To clearly define the limited scope of the MVP.
    * To prioritize features ruthlessly based on core value and learning objectives.
    * To enable faster time-to-market for the initial version.
    * To provide a focused guide for the development team building the MVP.
    * To articulate the key assumptions being tested by the MVP release.
* **Key Characteristics:**
    * **Minimalist:** Contains only the necessary requirements for the MVP.
    * **Focused:** Centers on the core value proposition and user problem.
    * **Action-Oriented:** Geared towards building, launching, and learning quickly.
    * **Flexible:** Expected to evolve based on feedback post-launch.
    * **Hypothesis-Driven:** Often explicitly states the assumptions the MVP aims to validate.
* **Typical Structure & Contents:**
    * **Product Vision/Goal (for MVP):** What specific goal does this MVP aim to achieve?
    * **Problem Statement:** The core user problem the MVP addresses.
    * **Target Users (Early Adopters):** Specific user segment targeted by the MVP.
    * **Key Features/User Stories (MVP Scope):** Prioritized list of essential features/stories ONLY for the MVP. Explicitly lists what's *out* of scope.
    * **Key Metrics/Success Criteria:** How will the success/failure of the MVP hypotheses be measured? (e.g., user sign-ups, completion rates of a core task, feedback scores).
    * **Riskiest Assumptions:** What core assumptions about users/market/technology is this MVP testing?
    * **(Optional) Core User Flow/Wireframes:** Simplified design sketches for the essential MVP workflow.
* **Pros:**
    * Significantly speeds up time-to-market for the first version.
    * Reduces initial development cost and risk.
    * Focuses effort on validating the core product idea.
    * Maximizes learning from real user feedback early on.
    * Minimizes wasted development effort on features users don't want.
* **Cons:**
    * Initial product may feel very basic or incomplete to some stakeholders or users.
    * Requires strong discipline to resist scope creep ("just one more feature...").
    * Defining "minimum" and "viable" correctly can be challenging.
    * May require significant follow-on investment to build a fully-featured product.

---

## 6. Functional Specification Document (FSD / FRD)

* **Core Philosophy:** Provide a detailed description of *how* a specific feature or the system as a whole will behave from a user's perspective. It translates the "what" (from PRD or user stories) into specific functional behavior without necessarily dictating the technical implementation.
* **Timing:** Can be created after a high-level PRD (in Waterfall) or derived from/elaborating on User Stories or Epics just before or during development (in Agile). It details requirements for a specific piece of functionality.
* **Purpose:**
    * To eliminate ambiguity about how a feature should function.
    * To provide clear instructions for developers on building the feature's logic and interactions.
    * To serve as a basis for writing functional test cases for QA.
    * To document specific business rules, data handling, and user interface interactions.
* **Key Characteristics:**
    * **Detailed & Specific:** Focuses on the precise behavior of functions and features.
    * **User-Interaction Focused:** Describes system responses to user actions ("When the user clicks X, the system does Y").
    * **Implementation Agnostic (Ideally):** Describes *what* functionally happens, not *how* it's coded (though lines can blur).
    * **Component-Level or Feature-Level:** Often created for individual features or modules rather than the entire product in one go.
* **Typical Structure & Contents:**
    * **Introduction/Feature Overview:** Purpose and scope of the function being specified.
    * **Assumptions/Dependencies:** Any prerequisites or conditions.
    * **Functional Requirements:**
        * Detailed breakdown of specific actions, system responses, calculations, and business logic.
        * Often uses numbered lists, use cases, or flowcharts.
    * **User Interface (UI) Details:** Descriptions of screens, fields, buttons, menus, and their behavior (may include mockups or wireframes).
    * **Data Handling:** How data is entered, validated, processed, stored, and displayed.
    * **Error Handling:** How the system should respond to errors or invalid inputs.
    * **Security Considerations (Functional):** Access controls, permissions related to the function.
    * **(Often overlaps with) Acceptance Criteria:** Specific conditions defining successful completion.
* **Pros:**
    * Greatly reduces ambiguity for developers and testers.
    * Ensures complex features are built according to detailed requirements.
    * Provides a clear, testable definition of functionality.
    * Useful for documenting complex business rules.
* **Cons:**
    * Can be very time-consuming to create and maintain, especially in rapidly changing Agile environments.
    * Risk of becoming overly detailed ("over-specification") and stifling implementation creativity or necessary adjustments.
    * Can quickly become outdated if not diligently updated alongside code changes.
    * Significant overlap with well-written User Stories and Acceptance Criteria in mature Agile teams.

These documents aren't always mutually exclusive. An MRD might feed into a Lean PRD for an MVP, and specific complex features within that MVP might warrant a detailed FSD (or highly detailed User Stories/AC in Agile). The key is choosing the right tool(s) for the level of detail, clarity, and flexibility needed for your specific project context and development methodology.

---

## 7. Key Differences Summarized (MRD, Lean/MVP, FSD)

| Feature         | Market Requirements Doc (MRD)      | Lean PRD / MVP Spec             | Functional Spec Doc (FSD)           |
| :-------------- | :--------------------------------- | :------------------------------ | :---------------------------------- |
| **Timing**      | Very Early (Pre-PRD/Backlog)       | Before MVP Development          | Pre/During Feature Development      |
| **Purpose**     | Justify Market Need ("Why")        | Define Core MVP ("What First")  | Detail Feature Behavior ("How")     |
| **Scope**       | Market Opportunity, High-Level Needs | Minimal Essential Features Only | Specific Feature(s) Functionality |
| **Detail Level**| Strategic, Market-Focused        | High-Level Features, Metrics    | Exhaustive Functional Details       |
| **Flexibility** | Moderate (Market Changes)          | High (Based on MVP Feedback)    | Lower (Defines Specific Behavior)   |
| **Primary Focus**| Market, Business Justification   | Validation, Learning, Speed     | Implementation Clarity, Test Basis  |