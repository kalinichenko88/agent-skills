import { useState, type ChangeEvent, type FormEvent } from 'react';

import type { Group } from './models/group';
import { useCreateGroup } from './use-create-group';
import { useGroupOptions } from './use-group-options';

type GroupSelectProps = {
  type: string;
  onChange: (group: Group) => void;
};

export function GroupSelect({ type, onChange }: GroupSelectProps) {
  const [selectedId, setSelectedId] = useState('');
  const [newName, setNewName] = useState('');

  const { options, addGroup } = useGroupOptions(type);
  const { creation, create } = useCreateGroup(type, (group) => {
    addGroup(group);
    setSelectedId(group.id);
    onChange(group);
  });

  const groups = options.status === 'done' ? options.groups : [];
  const isLoading = options.status === 'loading';
  const isCreating = creation.status === 'creating';
  const isSelectDisabled = isLoading || isCreating;
  const isCreateDisabled = isLoading || isCreating || newName.trim() === '';

  function handleSelect(event: ChangeEvent<HTMLSelectElement>) {
    const group = groups.find((item) => {
      return item.id === event.target.value;
    });

    if (group === undefined) {
      return;
    }

    setSelectedId(group.id);
    onChange(group);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (isCreateDisabled) {
      return;
    }

    const created = await create(newName.trim());

    if (created) {
      setNewName('');
    }
  }

  return (
    <div>
      <select value={selectedId} onChange={handleSelect} disabled={isSelectDisabled}>
        {isLoading ? <option value="">Loading…</option> : null}
        {groups.map((group) => {
          return (
            <option key={group.id} value={group.id}>
              {group.name}
            </option>
          );
        })}
      </select>

      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="New group name"
          value={newName}
          onChange={(event) => {
            setNewName(event.target.value);
          }}
          disabled={isCreating}
        />
        <button type="submit" disabled={isCreateDisabled}>
          Create
        </button>
      </form>

      {options.status === 'failed' ? <p role="alert">{options.message}</p> : null}
      {creation.status === 'failed' ? <p role="alert">{creation.message}</p> : null}
    </div>
  );
}
