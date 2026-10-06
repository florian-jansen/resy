# Internal Parallel Computing Utilities

Provides cross-platform wrappers around base R's parallel computing
functions. These utilities enable conditional parallelization that
gracefully falls back to sequential computation on Windows (where
\`parallel::mclapply()\` and \`parallel::mcmapply()\` are unavailable)
or when a single core is requested.

## Usage

``` r
.resy_mclapply(X, FUN, ..., mc = 1L, mc.cores = NULL)
```

## Details

The \`RESY\` package uses these wrapper functions to allow
parallelization of computationally intensive operations across different
operating systems and user configurations without requiring additional
dependencies.

\## Functions

\- \`.resy_mclapply()\`: Wraps \`parallel::mclapply()\` with Windows
compatibility and fallback to \`base::lapply()\` when parallelization is
not applicable.

\- \`.resy_mcmapply()\`: Wraps \`parallel::mcmapply()\` with Windows
compatibility and fallback to \`base::mapply()\` when parallelization is
not applicable.

\- \` otherwise returns the right operand. Used for parameter
defaulting.

\## Parallelization Rules

Parallel computation is applied only when: - Multiple cores are
requested (\`mc \> 1\` or \`mc.cores \> 1\`), AND - The operating system
supports fork-based parallelization (not Windows)

Otherwise, computations fall back to sequential operations.
