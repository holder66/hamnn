// show_test.v
module hamnn

// import os

// test_show_analyze has no asserts; the console output needs
// to be verified visually.
// fn test_show_analyze() {
// 	mut opts := Options{
// 		show_flag: false
// 	}
// 	mut ar := AnalyzeResult{}

// 	ar = analyze_dataset(load_file('datasets/developer.tab'), opts)
// 	show_analyze(ar)

// 	ar = analyze_dataset(load_file('datasets/iris.tab'), opts)
// 	show_analyze(ar)
// }

// test_show_append
// fn test_show_append() ? {
// 	opts := Options{
// 		show_flag: true
// 		testfile_path: 'datasets/test_validate.tab'
// 	}
// 	mut cl := Classifier{}
// 	mut ext_cl := Classifier{}
// 	cl = make_classifier(load_file('datasets/test.tab'), opts)
// 	mut instances_to_append := validate(cl, opts) ?
// 	show_classifier(append_instances(cl, instances_to_append, opts))
// }

// test_show_classifier
// fn test_show_classifier() {
// 	mut opts := Options{
// 		show_flag: true
// 	}
// 	mut ds := load_file('datasets/iris.tab')
// 	mut cl := make_classifier(ds, opts)
// }

// test_show_crossvalidation_result
fn test_show_crossvalidation_result() ? {
	mut cvr := VerifyResult{}
	mut opts := Options{
		show_flag: true
		concurrency_flag: true
		command: 'cross'
	}
	println('developer.tab')
	cvr = cross_validate(load_file('datasets/developer.tab'), opts)
	println('\n\ndeveloper.tab with expanded results')
	opts.expanded_flag = true
	cvr = cross_validate(load_file('datasets/developer.tab'), opts)

	println('\n\nbreast-cancer-wisconsin-disc.tab')
	opts.expanded_flag = false
	opts.number_of_attributes = [4]
	cvr = cross_validate(load_file('datasets/breast-cancer-wisconsin-disc.tab'), opts)
	println('\n\nbreast-cancer-wisconsin-disc.tab with expanded results')
	opts.expanded_flag = true
	cvr = cross_validate(load_file('datasets/breast-cancer-wisconsin-disc.tab'), opts)

	println('\n\niris.tab')
	opts.expanded_flag = false
	opts.bins = [3,6]
	opts.number_of_attributes = [2]
	cvr = cross_validate(load_file('datasets/iris.tab'), opts)
	println('\n\niris.tab with expanded results')
	opts.expanded_flag = true
	cvr = cross_validate(load_file('datasets/iris.tab'), opts)
}
