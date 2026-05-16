import os
import glob

run_dir = "scrolls-lab/logs/run_20260515_185541/iter_3"
sections_dir = os.path.join(run_dir, "sections")
optimized_dir = os.path.join(run_dir, "optimized")
output_file = ".scrolls/llms-full.txt"

section_files = sorted(glob.glob(os.path.join(sections_dir, "section_*.md")))

if not section_files:
    print("No sections found.")
else:
    with open(output_file, "w") as out:
        for sec_file in section_files:
            basename = os.path.basename(sec_file)
            opt_file = os.path.join(optimized_dir, basename)
            
            # Use optimized if it exists, otherwise fall back to the section file
            target = opt_file if os.path.exists(opt_file) else sec_file
            with open(target, "r") as f:
                content = f.read()
                out.write(content)

    print("Reassembled iter_3 into llms-full.txt.")
