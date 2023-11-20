import {Workspace} from 'blockly';
import {AnyDuringMigration} from '../util/types';

// TODO: Make a better version of this type
export type BlocklyWrapper = AnyDuringMigration;

export type GoogleBlocklyWorkspace = Workspace & {
  noFunctionBlockFrame?: boolean;
};
