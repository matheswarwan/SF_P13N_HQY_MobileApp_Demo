import Foundation

/// Static fallback content shown when the SF p13n SDK is unavailable or returns no decisions.
/// Also used as optimistic placeholder while the SDK call is in flight.
enum MockData {

    // MARK: - Featured Article (hero banner)

    static let featuredArticle = Article(
        id: "mock-featured-001",
        headline: "Maximize Your HSA in 2026: Contribution Limits & Tax Strategies",
        summary: "New IRS limits mean you can save even more in your Health Savings Account this year. Here's how to make the most of it.",
        body: """
        The IRS has announced increased contribution limits for Health Savings Accounts in 2026, \
        giving you an even greater opportunity to save on taxes while building a healthcare nest egg.

        2026 HSA Contribution Limits
        Individual coverage: $4,400
        Family coverage: $8,750
        Catch-up contribution (age 55+): additional $1,000

        Triple Tax Advantage
        HSAs remain one of the most powerful tax-advantaged accounts available. Contributions are \
        tax-deductible, growth is tax-free, and qualified withdrawals are tax-free. No other account \
        offers this triple benefit.

        Maximizing Your Contributions
        Consider front-loading your contributions early in the year to maximize investment growth. \
        If your employer offers HSA matching, ensure you contribute at least enough to capture the \
        full match — it's free money for your healthcare future.

        Investment Strategy
        Once your HSA balance exceeds your short-term medical expense needs, consider investing the \
        surplus. HealthEquity offers a range of investment options from low-cost index funds to \
        target-date funds designed for long-term growth.
        """,
        category: "HSA",
        imageURL: URL(string: "https://picsum.photos/seed/hsa2026/800/450"),
        publishedDate: Date(),
        readTimeMinutes: 6,
        isFeatured: true
    )

    // MARK: - For You Feed

    static let forYouArticles: [Article] = [
        Article(
            id: "mock-feed-001",
            headline: "FSA Eligible Expenses You Didn't Know About",
            summary: "Your Flexible Spending Account covers more than you think — from sunscreen to acupuncture.",
            body: """
            Flexible Spending Accounts can be used for a surprisingly wide range of health-related \
            expenses. Many participants leave money on the table simply because they don't know \
            what qualifies.

            Commonly Overlooked FSA-Eligible Expenses
            • Sunscreen (SPF 15+)
            • First aid kits
            • Acupuncture and chiropractic care
            • Prescription sunglasses
            • Menstrual care products
            • COVID-19 home tests
            • Bandages and wound care supplies

            The Use-It-or-Lose-It Rule
            Remember, most FSA funds expire at the end of the plan year. Some employers offer a \
            grace period of up to 2.5 months or a rollover of up to $640. Check your plan details \
            and spend strategically before the deadline.

            Pro Tip
            Keep receipts for all purchases. The HealthEquity mobile app lets you snap photos of \
            receipts and store them digitally for easy reimbursement.
            """,
            category: "FSA",
            imageURL: URL(string: "https://picsum.photos/seed/fsa/400/300"),
            publishedDate: Date(),
            readTimeMinutes: 4,
            isFeatured: false
        ),
        Article(
            id: "mock-feed-002",
            headline: "Open Enrollment Checklist: 5 Steps to Get It Right",
            summary: "Don't rush through open enrollment. Follow these steps to choose the best benefits package for your needs.",
            body: """
            Open enrollment is your annual opportunity to review and adjust your benefits. \
            Taking time to evaluate your options can save you thousands of dollars.

            Step 1: Review Last Year's Usage
            Look at your medical expenses from the past year. Did you hit your deductible? \
            Did you have unused FSA funds? This data helps you right-size your elections.

            Step 2: Evaluate Life Changes
            Marriage, a new baby, or a change in health status can shift which plan is best for you. \
            A high-deductible plan with an HSA may be ideal for healthy individuals, while a PPO \
            might be better if you anticipate frequent specialist visits.

            Step 3: Calculate Total Cost of Care
            Don't just look at premiums. Add up premiums, expected out-of-pocket costs, and \
            deductibles to find the true cost of each plan option.

            Step 4: Max Out Tax-Advantaged Accounts
            Contribute the maximum to your HSA or FSA. These pre-tax dollars reduce your taxable \
            income and provide funds for qualified medical expenses.

            Step 5: Review Dependent and Beneficiary Information
            Ensure all dependents are listed correctly and beneficiary designations are up to date.
            """,
            category: "Benefits",
            imageURL: URL(string: "https://picsum.photos/seed/enrollment/400/300"),
            publishedDate: Date(),
            readTimeMinutes: 5,
            isFeatured: false
        ),
        Article(
            id: "mock-feed-003",
            headline: "Investing Your HSA: A Beginner's Guide",
            summary: "Your HSA can double as a retirement account. Learn how to invest for long-term growth.",
            body: """
            Most people think of their HSA as a short-term spending account, but it can be one of \
            the most powerful long-term investment vehicles available.

            Why Invest Your HSA?
            Unlike an FSA, HSA funds never expire. Combined with the triple tax advantage, an \
            invested HSA can grow significantly over time. A $3,000 annual contribution invested \
            over 30 years at a 7% average return could grow to over $300,000.

            Getting Started
            HealthEquity makes it easy to invest your HSA. Once your cash balance exceeds your \
            chosen threshold, you can allocate surplus funds across a menu of investment options.

            Investment Options
            • Index funds tracking the S&P 500
            • Bond funds for conservative growth
            • Target-date funds based on your retirement year
            • Balanced funds mixing stocks and bonds

            Key Strategy: Pay Out of Pocket Now
            If you can afford to pay medical expenses from your regular income, let your HSA \
            investments grow. Save your receipts — you can reimburse yourself tax-free at any time \
            in the future, even decades later.
            """,
            category: "Investing",
            imageURL: URL(string: "https://picsum.photos/seed/invest/400/300"),
            publishedDate: Date(),
            readTimeMinutes: 7,
            isFeatured: false
        ),
        Article(
            id: "mock-feed-004",
            headline: "Wellness Programs That Actually Work",
            summary: "Evidence-based wellness initiatives that improve employee health and reduce costs.",
            body: """
            Workplace wellness programs have evolved significantly. The most effective programs \
            go beyond step challenges to address holistic well-being.

            What the Research Shows
            Companies with comprehensive wellness programs see 25% lower absenteeism and \
            measurable improvements in employee satisfaction. The key is offering programs people \
            actually want to use.

            High-Impact Wellness Benefits
            • Mental health support and EAP services
            • Preventive care incentives
            • Fitness reimbursements
            • Financial wellness education
            • Stress management resources

            Leveraging Your Benefits
            Many HealthEquity plans include wellness incentives that deposit funds directly into \
            your HSA when you complete qualifying activities like annual physicals, biometric \
            screenings, or health assessments.

            Getting Started
            Check your benefits portal for available wellness programs. Even small steps like \
            scheduling your annual physical can unlock HSA incentive contributions.
            """,
            category: "Wellness",
            imageURL: URL(string: "https://picsum.photos/seed/wellness/400/300"),
            publishedDate: Date(),
            readTimeMinutes: 5,
            isFeatured: false
        )
    ]

    // MARK: - Trending (always static — not personalized)

    static let trendingArticles: [Article] = [
        Article(
            id: "trend-001",
            headline: "2026 HSA & FSA Contribution Limits at a Glance",
            summary: "Quick reference for this year's IRS contribution limits across all benefit accounts.",
            body: """
            Here are the key contribution limits for 2026:

            HSA Limits
            • Individual: $4,400
            • Family: $8,750
            • Catch-up (55+): +$1,000

            FSA Limits
            • Healthcare FSA: $3,200
            • Dependent Care FSA: $5,000 (married filing jointly)
            • FSA Rollover Max: $640

            401(k) Limits
            • Employee contribution: $23,500
            • Catch-up (50+): +$7,500

            Plan your contributions early to maximize tax savings throughout the year.
            """,
            category: "Tax Savings",
            imageURL: nil,
            publishedDate: Date(),
            readTimeMinutes: 3,
            isFeatured: false
        ),
        Article(
            id: "trend-002",
            headline: "COBRA: What You Need to Know Before You Leave Your Job",
            summary: "Understanding your COBRA rights ensures continuous health coverage during transitions.",
            body: """
            If you're changing jobs or experiencing a qualifying life event, COBRA allows you to \
            continue your employer-sponsored health coverage for a limited time.

            Key COBRA Facts
            • Coverage can last 18 to 36 months depending on the qualifying event
            • You pay the full premium plus a 2% administrative fee
            • You have 60 days to elect COBRA after losing coverage
            • Coverage is retroactive to your loss-of-coverage date

            Is COBRA Right for You?
            Compare COBRA costs against marketplace plans. In some cases, an ACA marketplace plan \
            with premium subsidies may be more affordable. However, COBRA lets you keep your \
            existing doctors and network.

            HealthEquity COBRA Administration
            HealthEquity handles COBRA administration for many employers. Check your COBRA election \
            notice for login details to manage your coverage online.
            """,
            category: "COBRA",
            imageURL: nil,
            publishedDate: Date(),
            readTimeMinutes: 4,
            isFeatured: false
        ),
        Article(
            id: "trend-003",
            headline: "Commuter Benefits: Save on Your Daily Transit Costs",
            summary: "Pre-tax commuter benefits can save you hundreds of dollars annually on parking and transit.",
            body: """
            Commuter benefits allow you to set aside pre-tax dollars for qualified transportation \
            and parking expenses.

            2026 Monthly Limits
            • Transit/vanpool: $325/month
            • Qualified parking: $325/month
            • Combined: up to $650/month in pre-tax savings

            What Qualifies?
            • Public transit passes (bus, subway, train, ferry)
            • Vanpool expenses
            • Qualified parking at or near your workplace
            • Qualified parking at a transit station (park-and-ride)

            How Much Can You Save?
            At a 30% combined tax rate, maxing out both benefits saves approximately $2,340 \
            per year in taxes.

            Set up your commuter benefit elections through your HealthEquity account to start \
            saving on your next paycheck.
            """,
            category: "Commuter",
            imageURL: nil,
            publishedDate: Date(),
            readTimeMinutes: 5,
            isFeatured: false
        )
    ]
}
