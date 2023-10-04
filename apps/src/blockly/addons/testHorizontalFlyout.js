import GoogleBlockly from 'blockly/core';

export default class TestHorizontalFlyout extends GoogleBlockly.HorizontalFlyout {
  constructor(options) {
    super(options);
  }

  createBlock(originalBlock) {
    let newBlock = null;
    Blockly.Events.disable();
    const variablesBeforeCreation = this.targetWorkspace.getAllVariables();
    this.targetWorkspace.setResizesEnabled(false);
    try {
      newBlock = this.placeNewBlock(originalBlock);
    } finally {
      Blockly.Events.enable();
    }

    // Close the flyout.
    this.targetWorkspace.hideChaff();

    const newVariables = Blockly.Variables.getAddedVariables(
      this.targetWorkspace,
      variablesBeforeCreation
    );

    if (Blockly.Events.isEnabled()) {
      Blockly.Events.setGroup(true);
      // Fire a VarCreate event for each (if any) new variable created.
      for (let i = 0; i < newVariables.length; i++) {
        const thisVariable = newVariables[i];
        Blockly.Events.fire(
          new (Blockly.Events.get(Blockly.Events.VAR_CREATE))(thisVariable)
        );
      }

      // Block events come after var events, in case they refer to newly created
      // variables.
      Blockly.Events.fire(
        new (Blockly.Events.get(Blockly.Events.BLOCK_CREATE))(newBlock)
      );
    }
    if (this.autoClose) {
      this.hide();
    } else {
      this.filterForCapacity();
    }
    return newBlock;
  }

  placeNewBlock(oldBlock) {
    const targetWorkspace = this.targetWorkspace;
    const svgRootOld = oldBlock.getSvgRoot();
    if (!svgRootOld) {
      throw Error('oldBlock is not rendered');
    }

    // Clone the block.
    // TODO(#7432): Add a saveIds parameter to `save`.
    const json = Blockly.serialization.blocks.save(oldBlock);
    // Normallly this resizes leading to weird jumps. Save it for terminateDrag.
    targetWorkspace.setResizesEnabled(false);
    const block = Blockly.serialization.blocks.append(json, targetWorkspace);

    this.positionNewBlock(oldBlock, block);

    return block;
  }

  positionNewBlock(oldBlock, block) {
    const targetWorkspace = this.targetWorkspace;

    // The offset in pixels between the main workspace's origin and the upper
    // left corner of the injection div.
    const mainOffsetPixels = targetWorkspace.getOriginOffsetInPixels();

    // The offset in pixels between the flyout workspace's origin and the upper
    // left corner of the injection div.
    const flyoutOffsetPixels = this.workspace_.getOriginOffsetInPixels();

    // The position of the old block in flyout workspace coordinates.
    const oldBlockPos = oldBlock.getRelativeToSurfaceXY();

    console.log({mainOffsetPixels, flyoutOffsetPixels, oldBlockPos});
    // The position of the old block in pixels relative to the flyout
    // workspace's origin.
    oldBlockPos.scale(this.workspace_.scale);

    // The position of the old block in pixels relative to the upper left corner
    // of the injection div.
    const oldBlockOffsetPixels = Blockly.utils.Coordinate.sum(
      flyoutOffsetPixels,
      oldBlockPos
    );

    // The position of the old block in pixels relative to the origin of the
    // main workspace.
    const finalOffset = Blockly.utils.Coordinate.difference(
      oldBlockOffsetPixels,
      mainOffsetPixels
    );
    // The position of the old block in main workspace coordinates.
    finalOffset.scale(1 / targetWorkspace.scale);

    console.log({finalOffset});

    // No 'reason' provided since events are disabled.
    block.moveTo(new Blockly.utils.Coordinate(finalOffset.x, finalOffset.y));
  }
}
