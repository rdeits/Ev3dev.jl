import Base: next

immutable Transition
    test::Function
    destination
end

type Behavior
    action::Function
    transitions::Vector{Transition}

    Behavior(action::Function) = new(action, Transition[])
end

function add_transition!(behavior::Behavior, transition::Transition)
    push!(behavior.transitions, transition)
end

type BehaviorSet
    behaviors::Vector{Behavior}
    starting::Vector{Behavior}
    final::Behavior
end

function next(behavior::Behavior, args...)
    for transition in behavior.transitions
        if transition.test(args...)
            behavior = transition.destination
            break
        end
    end
    behavior
end