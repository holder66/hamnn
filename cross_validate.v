// cross_validate.v
module hamnn

import strconv
import runtime

// cross_validate takes a dataset and performs n-fold cross-validation.
// ```sh
// Options (also see the Options struct):
// bins: range for binning or slicing of continuous attributes;
// uniform_bins: same number of bins for continuous attributes;
// number_of_attributes: range for attributes to include;
// exclude_flag: excludes missing values when ranking attributes;
// weighting_flag: rank attributes and count nearest neighbors accounting
// for class prevalences;
// folds: number of folds n to use for n-fold cross-validation (default
// is leave-one-out cross-validation);
// repetitions: number of times to repeat n-fold cross-validations;
// random-pick: choose instances randomly for n-fold cross-validations.
// Output options:
// show_flag: prints results to the console;
// expanded_flag: prints additional information to the console, including
// 		a confusion matrix.
// ```
pub fn cross_validate(ds Dataset, opts Options) CrossVerifyResult {
	// to sort out what is going on, run the test file with concurrency off.
	mut cross_opts := opts
	cross_opts.datafile_path = ds.path
	mut folds := opts.folds
	mut fold_result := CrossVerifyResult{}

	// for each class, instantiate an entry in the confusion matrix map
	mut confusion_matrix_map := map[string]map[string]int{}
	for key1, _ in ds.class_counts {
		for key2, _ in ds.class_counts {
			confusion_matrix_map[key2][key1] = 0
		}
	}
	// instantiate a struct for the result
	mut cross_result := CrossVerifyResult{
		labeled_classes: ds.class_values
		class_counts: ds.class_counts
		pos_neg_classes: get_pos_neg_classes(ds.class_counts)
		confusion_matrix_map: confusion_matrix_map
	}
	// test if leave-one-out crossvalidation is requested
	if opts.folds == 0 {
		folds = ds.class_values.len
	}
	// if the concurrency flag is set
	if opts.concurrency_flag {
		mut result_channel := chan CrossVerifyResult{cap: folds}
		// queue all work + the sentinel values:
		jobs := runtime.nr_jobs()
		mut work_channel := chan int{cap: folds + jobs}
		for i in 0 .. folds {
			work_channel <- i
		}
		for _ in 0 .. jobs {
			work_channel <- -1
		}
		// start a thread pool to do the work:
		mut tpool := []thread{}
		for _ in 0 .. jobs {
			tpool << go option_worker(work_channel, result_channel, folds, ds, opts)
		}
		tpool.wait()
		//
		for _ in 0 .. folds {
			fold_result = <-result_channel
			cross_result.inferred_classes << fold_result.inferred_classes
			cross_result.actual_classes << fold_result.labeled_classes
			// cross_result = update_cross_result(fold_result, mut cross_result)
		}
	} else {
		// for each fold
		for current_fold in 0 .. folds {
			fold_result = do_one_fold(current_fold, folds, ds, cross_opts)
			cross_result.inferred_classes << fold_result.inferred_classes
			cross_result.actual_classes << fold_result.labeled_classes
			// cross_result = update_cross_result(fold_result, mut cross_result)
		}
	}
	cross_result = summarize_results(mut cross_result)
	// show_results(cross_result, cross_opts)
	if cross_opts.command == 'cross' && (cross_opts.show_flag || cross_opts.expanded_flag) {
		show_crossvalidation_result(cross_result, cross_opts)
	}
	return cross_result
}

// do_one_fold
fn do_one_fold(current_fold int, folds int, ds Dataset, cross_opts Options) CrossVerifyResult {
	mut byte_values_array := [][]byte{}
	// partition the dataset into a partial dataset and a fold
	part_ds, fold := partition(current_fold, folds, ds, cross_opts)
	// println('fold: $fold')
	mut fold_result := CrossVerifyResult{
		labeled_classes: fold.class_values
	}
	part_cl := make_classifier(part_ds, cross_opts)
	// println('part_cl.attribute_ordering: $part_cl.attribute_ordering')
	// for each attribute in the trained partition classifier
	for attr in part_cl.attribute_ordering {
		// get the index of the corresponding attribute in the fold
		j := fold.attribute_names.index(attr)
		// println('attr, j, fold.data[j]: $attr $j ${fold.data[j]}')
		// create byte_values for the fold data
		byte_values_array << process_fold_data(part_cl.trained_attributes[attr], fold.data[j])
	}
	// println('byte_values_array: $byte_values_array')
	fold_instances := transpose(byte_values_array)

	// println('fold_instances: $fold_instances')
	// for each class, instantiate an entry in the class table for the result
	// note that this needs to use the classes in the partition portion, not
	// the fold, so that wrong inferences get recorded properly.
	mut confusion_matrix_row := map[string]int{}
	// for each class, instantiate an entry in the confusion matrix row
	for key, _ in ds.Class.class_counts {
		confusion_matrix_row[key] = 0
	}
	fold_result = classify_to_verify(part_cl, fold_instances, mut fold_result, cross_opts)
	// println('fold_result: $fold_result')
	return fold_result
}

// process_fold_data
fn process_fold_data(part_attr TrainedAttribute, fold_data []string) []byte {
	// println('fold_data: $fold_data')
	mut byte_vals := []byte{cap: fold_data.len}

	// for a continuous attribute
	if part_attr.attribute_type == 'C' {
		values := fold_data.map(f32(strconv.atof_quick(it)))
		byte_vals << bin_values_array(values, part_attr.minimum, part_attr.maximum, part_attr.bins)
	} else {
		byte_vals << fold_data.map(byte(part_attr.translation_table[it]))
	}
	return byte_vals
}

// option_worker
fn option_worker(work_channel chan int, result_channel chan CrossVerifyResult, folds int, ds Dataset, opts Options) {
	for {
		mut current_fold := <-work_channel
		if current_fold < 0 {
			break
		}
		result_channel <- do_one_fold(current_fold, folds, ds, opts)
	}
}
