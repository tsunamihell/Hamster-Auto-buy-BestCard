import random

def genetic_algorithm(upgrades, max_budget, population_size=50, generations=100, mutation_rate=0.01):
    def create_individual():
        return [random.randint(0, 1) for _ in range(len(upgrades))]

    def fitness(individual):
        total_cost = sum(individual[i] * upgrades[i]["price"] for i in range(len(individual)))
        total_profit = sum(individual[i] * upgrades[i]["profitPerHourDelta"] for i in range(len(individual)))
        if total_cost > max_budget:
            return 0
        return total_profit

    def mutate(individual):
        for i in range(len(individual)):
            if random.random() < mutation_rate:
                individual[i] = 1 - individual[i]

    def crossover(parent1, parent2):
        point = random.randint(1, len(parent1) - 1)
        child1 = parent1[:point] + parent2[point:]
        child2 = parent2[:point] + parent1[point:]
        return child1, child2

    population = [create_individual() for _ in range(population_size)]

    for generation in range(generations):
        population = sorted(population, key=lambda ind: fitness(ind), reverse=True)
        next_population = population[:population_size//2]

        while len(next_population) < population_size:
            parent1, parent2 = random.sample(next_population, 2)
            child1, child2 = crossover(parent1, parent2)
            mutate(child1)
            mutate(child2)
            next_population.extend([child1, child2])

        population = next_population

    best_individual = max(population, key=lambda ind: fitness(ind))
    best_profit = fitness(best_individual)

    selected_upgrades = [upgrades[i] for i in range(len(best_individual)) if best_individual[i] == 1]

    return best_profit, selected_upgrades

# استفاده:
max_budget = 100000
best_profit, selected_upgrades = genetic_algorithm(upgrades, max_budget)

print(f"Best Profit: {best_profit}")
for upgrade in selected_upgrades:
    print(f"Upgrade ID: {upgrade['id']}, Profit: {upgrade['profitPerHourDelta']}, Price: {upgrade['price']}")
