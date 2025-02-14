Option Pricing Binomial


import numpy as np

def binomial_one_step(S, K, T, r, sigma, option_type='call'):
    """
    Price a European option using a one-step binomial tree model.
    
    Parameters:
    S (float): Current stock price
    K (float): Strike price
    T (float): Time to expiration (years)
    r (float): Risk-free rate (annualized)
    sigma (float): Volatility of the underlying asset
    option_type (str): 'call' or 'put'
    
    Returns:
    float: Option price rounded to 2 decimal places
    """
    # Input validation
    if option_type not in ['call', 'put']:
        raise ValueError("option_type must be 'call' or 'put'")
    if S <= 0 or K <= 0 or T <= 0 or sigma <= 0:
        raise ValueError("S, K, T, sigma must be positive")
    
    # Calculate up/down factors
    u = np.exp(sigma * np.sqrt(T))
    d = np.exp(-sigma * np.sqrt(T))
    
    if u == d:
        raise ValueError("u and d factors are equal; check parameters")
    
    # Compute stock prices at expiration
    S_u = S * u
    S_d = S * d
    
    # Option payoffs at expiration
    if option_type == 'call':
        f_u = max(S_u - K, 0)
        f_d = max(S_d - K, 0)
    else:
        f_u = max(K - S_u, 0)
        f_d = max(K - S_d, 0)
    
    # Risk-neutral probability
    p = (np.exp(r * T) - d) / (u - d)
    
    if p < 0 or p > 1:
        raise ValueError("No-arbitrage condition violated: p must be between 0 and 1")
    
    # Discount factor and option price
    discount = np.exp(-r * T)
    option_price = discount * (p * f_u + (1 - p) * f_d)
    
    return round(option_price, 2)

# Example usage
S = 100    # Current stock price
K = 100    # Strike price
T = 1      # Time to expiration (1 year)
r = 0.05   # Risk-free rate (5%)
sigma = 0.2  # Volatility (20%)

call_price = binomial_one_step(S, K, T, r, sigma, 'call')
put_price = binomial_one_step(S, K, T, r, sigma, 'put')

print(f"European Call Price (1-step): ${call_price}")
print(f"European Put Price (1-step): ${put_price}")
