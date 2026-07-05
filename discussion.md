# Design-Decisions

To foster the collaborative development of the package all discussions/decisions about scope, general structure and functionality of the packages should be documented and discussed here.

## Scope of the package

A toolbox to classify plant species co-occurrence matrices, 
   aka vegetation plots with formalised, rule based so-called "expert systems". 
   The ideas for such rule-based assignments go back to the 1990th but the application has gained
   momentum with the development of an expert system for the European Habitat Type (EUNIS).
   This package aims at a general implementation of the expert-system logic, 
   including tools to develop and check new expert systems. 
   Expert systems use indicator species groups, their abundances,
   presence or the (relative) amount of species of an indicator group.
   Furthermore, header data like the geographic location can be used to 
   identify e.g. an ecoregion, the country or if the plot is located on the coast,
   which is e.g. needed for the EUNIS expert system.
   The expert system for the plot assignment to European EUNIS habitat types is used as an example 
   throughout the package and additional helper functions 
   to prepare data for the EUNIS classification are included.
   
## Decisions/questions

 - version 1 of the package aims at a simple but generic implementation
 - a CRAN submission is intended, that means helper data (e.g. to prepare data for the EUNIS classification) has to be small enough
 - a test driven development is desirable
 - a better standardisation, including a json format of the expert-system file, completeness of available 
 formal rules and tests for checking the correct execution of these rules is intended
 - a shiny app for development, curation and test of expert systems is to be included
 - the EUNIS classification is used as an example  
   - specialised helper functions for the EUNIS classification are integrated but should be named as such or used internally
 
 
 