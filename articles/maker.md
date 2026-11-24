# RESY Maker

Build an expert system: each vegetation type gets a rule of conditions
on species groups. As you build, RESY classifies a set of test plots
with it. Export the system for the [RESY
App](https://florian-jansen.github.io/resy/articles/app.md) or
[`resy_classify()`](https://florian-jansen.github.io/resy/reference/resy_classify.md).
Runs in this browser tab through
[webR](https://docs.r-wasm.org/webr/latest/); nothing is uploaded.

![](../logo.png)![RESY](../logo.png)

Starting R…

Undo

Redo

Open…

Save

Clear…

Export…

Upload your plots

Open another system

An empty system You add the types, their groups and the species. The
Apennine example A small system with four species groups and five types
that fits the example plots. EUNIS-ESy European habitat types (Chytrý et
al. 2020), to adapt to your region or data. An expert system file
`.json` or `.txt`, to continue or change it.

Open

Clear everything?

Clear everything

Save a copy first

Cancel

Add the names of the test plots

Add the names

Cancel

Your plots

Species file: one row per species in each plot

Plot Species Cover (%)

Sites file: the plot column and the columns your rules read

Test on these files

Use the example plots again

Check

Export

Description

Download `.json`

Download `.txt`

Classify your data with it in the RESY App

The `.json` file is the format RESY reads directly. The `.txt` file has
the layout of the EUNIS-ESy releases; RESY reads it back after writing
it and compares it with the `.json` file. A system that starts from a
shipped one needs its own name once you change it. In R:

``` mb-0
```

This is the Apennine example: a few vegetation types, each with a rule
that is tested on the example plots. Change a rule and watch the plot
counts, or start your own system under **Open…**. ✕

Types

New type

&nbsp;

Test on a region

Test on all plots

Groups

Species

Plots

New group

Add species…

Add the names of the test plots…

Add to the list

Put them back

| Plot | Type | Rules that hold |
|------|------|-----------------|

✕
