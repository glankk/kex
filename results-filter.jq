[ foreach inputs as $item (0; .+1; {config: $ARGS.positional[.-1], results: $item}) ]
| . as $runs
| [$runs[].results.tests.[] | .name]
| unique
| map(. as $name | {
	name: $name,
	results: $runs | map(. as $run | $run.results.tests.[] | select(.name == $name) as $result | {
		config: $run.config,
		compile_time: $result.metrics.["compile_time"],
		exec_time: $result.metrics.["exec_time"],
		spills: $result.metrics.["regalloc.NumSpills"],
		code: $result.code
	})
})
