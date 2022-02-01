// append.v
module append

import tools
import json
import os
import time

// append appends instances in a file, to a classifier in a file specified
// by flag -k, and (optionally) stores the extended classifier in a file
// specified by -o. It returns the extended classifier.
pub fn append(cl tools.Classifier, instances_to_append tools.ValidateResult, opts tools.Options) tools.Classifier {
	// append needs to append the array of byte values for each new instance
	// to cl.instances, and append the class value for each new instance
	// cl.class_values, update the cl.class_counts map, and calculate a new lcm
	// println(cl)
	if opts.verbose_flag {
		println('$cl\n$instances_to_append')
	}
	mut ext_cl := cl
	ext_cl.instances_appended << [instances_to_append.inferred_classes.len]
	ext_cl.append_dates << [time.utc()]
	ext_cl.append_environment << [tools.get_environment()]
	ext_cl.instances << instances_to_append.instances
	ext_cl.class_values << instances_to_append.inferred_classes
	ext_cl.class_counts = tools.string_element_counts(ext_cl.class_values)
	// when the weighting_flag is set
	if opts.weighting_flag {
		ext_cl.lcm_class_counts = i64(tools.lcm(tools.get_map_values(ext_cl.class_counts)))
	}

	return ext_cl
}

// append_file_to_file extends the classifier in the file specified by
// opts.classifierfile_path, with the instances in the file specified
// by opts.instancesfile_path, and writes the extended classifier to a file
// specified by opts.outputfile_path
pub fn append_file_to_file(opts tools.Options) ?tools.Classifier {
	// println(opts)
	mut instances_to_append := tools.ValidateResult{}
	mut cl := tools.Classifier{}
	mut ext_cl := tools.Classifier{}
	cl = tools.load_classifier_file(opts.classifierfile_path) ?
	instances_to_append = tools.load_instances_file(opts.instancesfile_path) ?
	ext_cl = append(cl, instances_to_append, opts)
	if opts.show_flag {
		tools.show_classifier(ext_cl)
	}
	if opts.outputfile_path != '' && opts.command == 'append' {
		s := json.encode(ext_cl)
		// println('After json encoding, before writing:\n $s')
		mut f := os.open_file(opts.outputfile_path, 'w') or { panic(err.msg) }
		f.write_string(s) or { panic(err.msg) }
		f.close()
	}
	return ext_cl
}
