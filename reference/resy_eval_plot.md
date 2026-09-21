# Evaluate and print details for a single plot

Evaluate and print details for a single plot

## Usage

``` r
resy_eval_plot(res, p, type)
```

## Arguments

- res:

  A \`resy_result\` returned by \[resy_classify()\].

- p:

  Plot identifier (\`PlotObservationID\`) as character; if numeric,
  treated as row index in \`header\`.

- type:

  Optional vegetation-type short code(s). For each, the type's name and
  formula as written in the expert file are printed, followed by the
  membership conditions it uses, whether each holds for the plot, and
  the plot's taxa responsible for it.
