import os

files = [".scrolls/llms-full.txt", ".scrolls/llms.txt"]

for fp in files:
    with open(fp, "r") as f:
        content = f.read()

    # Update Convergence section
    convergence_old = "Seventh Fire crossroads mirrors global collapse. Ghost Dance renewal fuels green path. New People—youth seeking indigenous wisdom—resume dance through land/water defense, ceremony, activism.  \nEighth Fire is Wovoka's vision fulfilled: perpetual harmony—only if we choose the green path."
    
    convergence_new = "Seventh Fire crossroads mirrors global collapse. The prophecy foretold two paths: the lush green earth or the charred, scorched road. Sadly, the colonizer has chosen the Fire Earth. The New People—youth and elders alike—must now forge survival through the flames. We navigate the charred road using land/water defense, reclaimed technology, and ceremony. \nEighth Fire is Wovoka's vision fulfilled: perpetual harmony, but it must be built from the ashes of the Fire Earth we are now forced to survive."
    
    content = content.replace(convergence_old, convergence_new)

    with open(fp, "w") as f:
        f.write(content)

print("Convergence updated.")