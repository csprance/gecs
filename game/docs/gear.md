
# Gear System Documentation

This document describes how the gear system works, including examples of how gear items are combined using `Inputs` and `Outputs`.

## Overview

The gear system allows for dynamic assembly of gear items on characters by connecting gear pieces through matching `Inputs` and `Outputs`.

## How It Works

- **Inputs and Outputs:**
  - Each gear item has `Inputs` and `Outputs` nodes.
  - `Outputs` from one gear item can connect to `Inputs` of another gear item.

- **Attachment to Bones:**
  - Base gear items are attached to character bones using `BoneAttachment3D` nodes.
  - For example, a mask gear item can be attached to the head bone.

- **Transform Synchronization:**
  - `RemoteTransform3D` nodes copy transforms from `Outputs` to corresponding `Inputs`.
  - This ensures that connected gear items move together correctly.

## Example: Mask and Mask Topper

### Gear Items

- **Mask (`gear_mask.tscn`):**
  - Attached to the head bone.
  - Has an `Outputs/Mask` node with a `RemoteTransform3D` pointing to the mask mesh.
  
- **Mask Topper (`gear_mask_topper.tscn`):**
  - Designed to attach to the mask.
  - Placed under the `Inputs/Mask` node.

### Assembly Process

1. **Attach Mask to Character:**
   - The mask is attached to the character's head bone via `BoneAttachment3D`.
   
2. **Connect Mask Topper to Mask:**
   - The mask's `Outputs/Mask` node is connected to the mask topper's `Inputs/Mask` node.
   - A `RemoteTransform3D` copies the mask's transform to the mask topper.

3. **Result:**
   - The mask topper follows the mask's movements, which is attached to the head bone.
   - Additional gear items can be connected similarly, building complex gear assemblies.

## Conclusion

By using `Inputs` and `Outputs` with `RemoteTransform3D`, gear items can be modularly combined, allowing for flexible and dynamic gear configurations on characters.