# Tool comparison figure, redrawn from the result tables of the Windows run.
# The measurements themselves run outside targets (scripts/run/harness.py,
# scripts/run/task3/run.py); see topics/tool_comparison/README.md.
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
  ),
  # Task 4 (Supplementary Figure S13), measured on a Mac with
  # scripts/run/task4/; see the Task 4 section of the README.
  tar_target(
    tool_comparison_task4_results,
    file.path(
      "topics/tool_comparison/results/task4",
      c("task4_build.csv", "task4_deploy.csv", "task4_state.csv", "task4_update.csv")
    ),
    format = "file"
  ),
  tar_target(
    tool_comparison_task4_figure,
    plot_task4_figure(
      tool_comparison_task4_results[[1]],
      tool_comparison_task4_results[[2]],
      tool_comparison_task4_results[[3]],
      tool_comparison_task4_results[[4]],
      "topics/tool_comparison/figures"
    ),
    format = "file"
  )
)
