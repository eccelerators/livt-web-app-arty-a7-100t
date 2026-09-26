# Follow combinational area optimization with sequential resynthesis. The
# composed HTTP design otherwise exceeds slice packing capacity on the A7-100T.
# Keep normal timing/DRC checks; this does not relax timing constraints.
opt_design -directive ExploreSequentialArea
