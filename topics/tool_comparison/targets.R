# Tool comparison figure, redrawn from the result tables of the Windows run.
# The measurements themselves run outside targets (scripts/harness.py,
# scripts/task3.py); see topics/tool_comparison/README.md.
targets_tool_comparison <- list(
  tar_target(
    tool_comparison_results,
    file.path(
      "topics/tool_comparison/results",
      c("task1_summary.csv", "task2_summary.csv", "summary_task3.csv")
    ),
    format = "file"
  ),
  tar_target(
    tool_comparison_figure,
    plot_tool_comparison(
      tool_comparison_results[[1]],
      tool_comparison_results[[2]],
      tool_comparison_results[[3]],
      "topics/tool_comparison/figures"
    ),
    format = "file"
  )
)
